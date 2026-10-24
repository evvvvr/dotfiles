"""
Test Explorer: hierarchical view of Rust tests with run / ignore-toggle buttons
and real-time pass/fail/skip status badges.
"""
from __future__ import annotations

import sublime
from typing import Dict, List, Optional, Tuple

from . import finder, runner, status_store

EXPLORER_TITLE = 'Rust Test Explorer'

_C_RUN    = 'color: var(--greenish, #4ec9b0); text-decoration: none; padding: 0 2px;'
_C_SKIP   = 'color: var(--yellowish, #e5c07b); text-decoration: none; padding: 0 2px;'
_C_ENABLE = 'color: var(--bluish, #61afef);   text-decoration: none; padding: 0 2px;'
_C_DIM    = 'color: #666688; text-decoration: none; padding: 0 2px;'


class ExplorerView:
    _instances: Dict[int, 'ExplorerView'] = {}

    def __init__(self, window: sublime.Window):
        self.window   = window
        self._view:       Optional[sublime.View]       = None
        self._phantoms:   Optional[sublime.PhantomSet] = None
        self._scan:       List                         = []   # last scan_project result
        self._buf:        List[str]                    = []   # rendered lines
        self._node_lines: List[Tuple[int, finder.TestNode]] = []

    # ------------------------------------------------------------------ #
    # Public API
    # ------------------------------------------------------------------ #

    @classmethod
    def for_window(cls, window: sublime.Window) -> 'ExplorerView':
        wid = window.id()
        if wid not in cls._instances:
            cls._instances[wid] = cls(window)
        return cls._instances[wid]

    def show(self):
        if self._view and self._view.is_valid():
            self.window.focus_view(self._view)
            return
        v = self.window.new_file()
        v.set_name(EXPLORER_TITLE)
        v.set_scratch(True)
        v.set_read_only(True)
        v.settings().set('gutter', False)
        v.settings().set('line_numbers', False)
        v.settings().set('word_wrap', False)
        v.settings().set('rust_test_explorer', True)
        self._view     = v
        self._phantoms = sublime.PhantomSet(v, 'rust_test_btns')
        self.refresh()

    def refresh(self):
        """Re-scan project files and re-render."""
        if not (self._view and self._view.is_valid()):
            return
        root = self._get_cargo_root()
        self._scan = finder.scan_project(root) if root else []
        self._render(root)

    def redraw_status(self):
        """Re-place phantoms only (uses cached layout). Called on every test result."""
        if self._view and self._view.is_valid() and self._buf:
            self._place_phantoms(self._buf, self._node_lines)

    # ------------------------------------------------------------------ #
    # Internal
    # ------------------------------------------------------------------ #

    def _render(self, root: Optional[str]):
        if not (self._view and self._view.is_valid()):
            return

        buf: List[str]                              = []
        node_lines: List[Tuple[int, finder.TestNode]] = []

        buf.append(f'  {EXPLORER_TITLE}')
        buf.append('')

        if not self._scan:
            buf.append('  No Cargo.toml found.' if not root else '  No tests found.')
        else:
            for relpath, nodes in self._scan:
                buf.append(f'  {relpath}')
                self._collect(nodes, buf, node_lines, indent=2)
                buf.append('')

        self._buf        = buf
        self._node_lines = node_lines
        self._write('\n'.join(buf))
        self._place_phantoms(buf, node_lines)

    def _collect(
        self,
        nodes: List[finder.TestNode],
        buf: List[str],
        node_lines: List[Tuple[int, finder.TestNode]],
        indent: int,
    ):
        pad = '  ' * indent
        for node in nodes:
            icon = '▸ ' if node.is_suite else '  '
            node_lines.append((len(buf), node))
            buf.append(f'{pad}{icon}{node.name}')
            if node.children:
                self._collect(node.children, buf, node_lines, indent + 1)

    def _place_phantoms(
        self,
        buf: List[str],
        node_lines: List[Tuple[int, finder.TestNode]],
    ):
        if not self._view or not self._phantoms:
            return
        wid      = self.window.id()
        phantoms = []

        # Run-All button on the title line
        title_end = self._view.line(self._view.text_point(0, 0)).end()
        phantoms.append(sublime.Phantom(
            sublime.Region(title_end),
            f'<body><a href="run|" style="{_C_RUN}"> ▶ Run All</a></body>',
            sublime.LAYOUT_INLINE,
            on_navigate=self._on_navigate,
        ))

        for line_idx, node in node_lines:
            if line_idx >= len(buf):
                continue
            end = self._view.line(self._view.text_point(line_idx, 0)).end()

            # Status badge
            if not node.is_suite:
                st = status_store.get(wid, node.cargo_filter)
                icon, color = status_store.BADGE[st]
                if icon:
                    badge_html = (
                        f'<body><span style="color:{color}; padding: 0 3px;">'
                        f'{icon}</span></body>'
                    )
                    phantoms.append(sublime.Phantom(
                        sublime.Region(end), badge_html,
                        sublime.LAYOUT_INLINE, on_navigate=self._on_navigate,
                    ))

            # Run button
            run_icon  = '▶▶' if node.is_suite else '▶'
            run_style = _C_DIM if (not node.is_suite and node.ignored) else _C_RUN
            run_href  = f'run|{node.cargo_filter}'
            phantoms.append(sublime.Phantom(
                sublime.Region(end),
                f'<body><a href="{run_href}" style="{run_style}"> {run_icon}</a></body>',
                sublime.LAYOUT_INLINE, on_navigate=self._on_navigate,
            ))

            # Toggle-ignore button (test fns only)
            if not node.is_suite:
                if node.ignored:
                    tog_icon, tog_style = '↺', _C_ENABLE
                else:
                    tog_icon, tog_style = '⏸', _C_SKIP
                tog_href = f'toggle|{node.file}|{node.line}|{1 if node.ignored else 0}'
                phantoms.append(sublime.Phantom(
                    sublime.Region(end),
                    f'<body><a href="{tog_href}" style="{tog_style}"> {tog_icon}</a></body>',
                    sublime.LAYOUT_INLINE, on_navigate=self._on_navigate,
                ))

        self._phantoms.update(phantoms)

    def _on_navigate(self, href: str):
        parts  = href.split('|', 3)
        scheme = parts[0]
        if scheme == 'run':
            f = parts[1] if len(parts) > 1 and parts[1] else None
            self.window.run_command('rust_test_run', {'filter': f})
        elif scheme == 'toggle':
            _, fpath, line_str, ignored_str = parts
            self.window.run_command('rust_test_toggle_ignore', {
                'file': fpath, 'fn_line': int(line_str),
                'has_ignore': ignored_str == '1',
            })

    def _write(self, text: str):
        v = self._view
        if not v:
            return
        v.set_read_only(False)
        v.run_command('select_all')
        v.run_command('right_delete')
        v.run_command('append', {'characters': text, 'force': True})
        v.set_read_only(True)

    def _get_cargo_root(self) -> Optional[str]:
        for folder in self.window.folders():
            root = runner.find_cargo_root(folder)
            if root:
                return root
        av = self.window.active_view()
        if av and av.file_name():
            return runner.find_cargo_root(av.file_name())
        return None
