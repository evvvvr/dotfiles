"""
Test Explorer: a dedicated Sublime Text view that shows the project's
Rust test tree and provides clickable ▶ / ▶▶ buttons.
"""
from __future__ import annotations

import sublime
from typing import Dict, List, Optional, Tuple

from . import finder, runner

EXPLORER_TITLE = 'Rust Test Explorer'
BTN_STYLE = (
    'color: var(--greenish, #4ec9b0); '
    'text-decoration: none; '
    'padding: 0 3px;'
)


class ExplorerView:
    _instances: Dict[int, 'ExplorerView'] = {}

    def __init__(self, window: sublime.Window):
        self.window = window
        self._view: Optional[sublime.View] = None
        self._phantoms: Optional[sublime.PhantomSet] = None

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
        self._view = v
        self._phantoms = sublime.PhantomSet(v, 'rust_test_btns')
        self.refresh()

    def refresh(self):
        if not (self._view and self._view.is_valid()):
            return
        root = self._get_cargo_root()
        if not root:
            self._write('  No Cargo.toml found in project folders.\n')
            return

        scan = finder.scan_project(root)

        buf: List[str] = []
        node_lines: List[Tuple[int, finder.TestNode]] = []

        buf.append(f'  {EXPLORER_TITLE}')
        buf.append('')

        if not scan:
            buf.append('  No tests found.')
        else:
            for relpath, nodes in scan:
                buf.append(f'  {relpath}')
                self._collect(nodes, buf, node_lines, indent=2)
                buf.append('')

        self._write('\n'.join(buf))
        self._place_phantoms(buf, node_lines)

    # ------------------------------------------------------------------ #
    # Internal helpers
    # ------------------------------------------------------------------ #

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
        phantoms = []

        # "Run All" button on the title line
        pos = self._view.line(self._view.text_point(0, 0)).end()
        phantoms.append(sublime.Phantom(
            sublime.Region(pos),
            f'<body><a href="run_all" style="{BTN_STYLE}"> ▶ Run All</a></body>',
            sublime.LAYOUT_INLINE,
            on_navigate=self._on_navigate,
        ))

        for line_idx, node in node_lines:
            if line_idx >= len(buf):
                continue
            line_region = self._view.line(self._view.text_point(line_idx, 0))
            icon = '▶▶' if node.is_suite else '▶'
            action = f'run:{node.cargo_filter}'
            html = f'<body><a href="{action}" style="{BTN_STYLE}"> {icon}</a></body>'
            phantoms.append(sublime.Phantom(
                sublime.Region(line_region.end()),
                html,
                sublime.LAYOUT_INLINE,
                on_navigate=self._on_navigate,
            ))

        self._phantoms.update(phantoms)

    def _on_navigate(self, href: str):
        if href == 'run_all':
            self.window.run_command('rust_test_run', {'filter': None})
        elif href.startswith('run:'):
            self.window.run_command('rust_test_run', {'filter': href[4:]})

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
