"""
Inline phantoms in .rs source files: status badge, ▶ run, ⏸/↺ ignore toggle.
"""
from __future__ import annotations

import sublime
from typing import Dict, List, Optional

from . import finder, status_store

_C_RUN    = 'color: var(--greenish, #4ec9b0); text-decoration: none; padding: 0 2px;'
_C_SKIP   = 'color: var(--yellowish, #e5c07b); text-decoration: none; padding: 0 2px;'
_C_ENABLE = 'color: var(--bluish, #61afef);   text-decoration: none; padding: 0 2px;'
_C_DIM    = 'color: #666688; text-decoration: none; padding: 0 2px;'

_sets:  Dict[int, sublime.PhantomSet]    = {}  # view.id() → PhantomSet
_cache: Dict[int, List[finder.TestNode]] = {}  # view.id() → flat node list


def update(view: sublime.View):
    """Full update: re-parse the file, rebuild cache, re-place phantoms."""
    fname = view.file_name()
    if not fname or not fname.endswith('.rs'):
        return

    nodes = finder.find_tests(view.substr(sublime.Region(0, view.size())), fname)
    flat: List[finder.TestNode] = []
    _flatten(nodes, flat)
    _cache[view.id()] = flat

    ps = _sets.get(view.id())
    if ps is None:
        ps = sublime.PhantomSet(view, 'rust_test_inline')
        _sets[view.id()] = ps

    _place(view, flat, ps)
    _fade_ignored(view, flat)


def redraw_status(view: sublime.View):
    """Status-only refresh: use cached nodes, re-place phantoms with fresh status."""
    flat = _cache.get(view.id())
    ps   = _sets.get(view.id())
    if flat is not None and ps is not None:
        _place(view, flat, ps)


def clear(view: sublime.View):
    ps = _sets.pop(view.id(), None)
    if ps:
        ps.update([])
    _cache.pop(view.id(), None)
    view.erase_regions('rust_test_ignored')


# ------------------------------------------------------------------ #
# Internal
# ------------------------------------------------------------------ #

def _place(view: sublime.View, flat: List[finder.TestNode], ps: sublime.PhantomSet):
    w   = view.window()
    wid = w.id() if w else -1
    phantoms = []

    for node in flat:
        if node.is_suite:
            continue
        line_end = view.line(view.text_point(node.line, 0)).end()

        # Status badge
        st = status_store.get(wid, node.cargo_filter)
        icon, color = status_store.BADGE[st]
        if icon:
            phantoms.append(sublime.Phantom(
                sublime.Region(line_end),
                f'<body><span style="color:{color}; padding: 0 3px;">{icon}</span></body>',
                sublime.LAYOUT_INLINE,
                on_navigate=lambda href, v=view: _on_navigate(v, href),
            ))

        # Run button
        run_style = _C_DIM if node.ignored else _C_RUN
        run_href  = f'run|{node.cargo_filter}'
        phantoms.append(sublime.Phantom(
            sublime.Region(line_end),
            f'<body><a href="{run_href}" style="{run_style}"> ▶</a></body>',
            sublime.LAYOUT_INLINE,
            on_navigate=lambda href, v=view: _on_navigate(v, href),
        ))

        # Toggle-ignore button
        tog_icon, tog_style = ('↺', _C_ENABLE) if node.ignored else ('⏸', _C_SKIP)
        tog_href = f'toggle|{node.file}|{node.line}|{1 if node.ignored else 0}'
        phantoms.append(sublime.Phantom(
            sublime.Region(line_end),
            f'<body><a href="{tog_href}" style="{tog_style}"> {tog_icon}</a></body>',
            sublime.LAYOUT_INLINE,
            on_navigate=lambda href, v=view: _on_navigate(v, href),
        ))

    ps.update(phantoms)


def _fade_ignored(view: sublime.View, flat: List[finder.TestNode]):
    """
    Mark ignored test attribute blocks with a solid underline using the
    'comment' scope color (gray + italic in most dark themes).
    Covers from the topmost #[...] attribute above the fn line down to
    the fn declaration itself, so the whole header reads as inactive.
    """
    regions = []
    lines = view.substr(sublime.Region(0, view.size())).splitlines()
    for node in flat:
        if node.is_suite or not node.ignored:
            continue
        # Walk back from the fn line through consecutive attribute lines
        top = node.line
        for row in range(node.line - 1, max(node.line - 10, -1), -1):
            if row < len(lines) and lines[row].strip().startswith('#['):
                top = row
            else:
                break
        start = view.text_point(top, 0)
        end   = view.line(view.text_point(node.line, 0)).end()
        regions.append(sublime.Region(start, end))

    if regions:
        view.add_regions(
            'rust_test_ignored',
            regions,
            scope='comment',
            flags=sublime.DRAW_SOLID_UNDERLINE
                  | sublime.DRAW_NO_FILL
                  | sublime.DRAW_NO_OUTLINE,
        )
    else:
        view.erase_regions('rust_test_ignored')


def _flatten(nodes: List[finder.TestNode], result: List[finder.TestNode]):
    for node in nodes:
        result.append(node)
        if node.children:
            _flatten(node.children, result)


def _on_navigate(view: sublime.View, href: str):
    w = view.window()
    if not w:
        return
    parts  = href.split('|', 3)
    scheme = parts[0]
    if scheme == 'run':
        f = parts[1] if len(parts) > 1 and parts[1] else None
        w.run_command('rust_test_run', {'filter': f})
    elif scheme == 'toggle':
        _, fpath, line_str, ignored_str = parts
        w.run_command('rust_test_toggle_ignore', {
            'file': fpath, 'fn_line': int(line_str),
            'has_ignore': ignored_str == '1',
        })
