"""
Inline phantoms injected next to #[test] fn declarations in open .rs files.
Shows a ▶ run button and a ⏸/↺ ignore-toggle button.
"""
from __future__ import annotations

import sublime
from typing import Dict, List

from . import finder

_C_RUN    = 'color: var(--greenish, #4ec9b0); text-decoration: none; padding: 0 2px;'
_C_SKIP   = 'color: var(--yellowish, #e5c07b); text-decoration: none; padding: 0 2px;'
_C_ENABLE = 'color: var(--bluish, #61afef);   text-decoration: none; padding: 0 2px;'
_C_DIM    = 'color: #666688; text-decoration: none; padding: 0 2px;'

_sets: Dict[int, sublime.PhantomSet] = {}  # view.id() → PhantomSet


def update(view: sublime.View):
    fname = view.file_name()
    if not fname or not fname.endswith('.rs'):
        return

    content = view.substr(sublime.Region(0, view.size()))
    nodes   = finder.find_tests(content, fname)

    ps = _sets.get(view.id())
    if ps is None:
        ps = sublime.PhantomSet(view, 'rust_test_inline')
        _sets[view.id()] = ps

    flat: List[finder.TestNode] = []
    _flatten(nodes, flat)

    phantoms = []
    for node in flat:
        if node.is_suite:
            continue  # suites have no meaningful inline run button
        line_end = view.line(view.text_point(node.line, 0)).end()

        # Run button
        run_style = _C_RUN if not node.ignored else _C_DIM
        run_href  = f'run|{node.cargo_filter}'
        run_html  = f'<body><a href="{run_href}" style="{run_style}"> ▶</a></body>'
        phantoms.append(sublime.Phantom(
            sublime.Region(line_end), run_html,
            sublime.LAYOUT_INLINE,
            on_navigate=lambda href, v=view: _on_navigate(v, href),
        ))

        # Toggle ignore button
        if node.ignored:
            tog_icon, tog_style = '↺', _C_ENABLE
        else:
            tog_icon, tog_style = '⏸', _C_SKIP
        tog_href = f'toggle|{node.file}|{node.line}|{1 if node.ignored else 0}'
        tog_html = f'<body><a href="{tog_href}" style="{tog_style}"> {tog_icon}</a></body>'
        phantoms.append(sublime.Phantom(
            sublime.Region(line_end), tog_html,
            sublime.LAYOUT_INLINE,
            on_navigate=lambda href, v=view: _on_navigate(v, href),
        ))

    ps.update(phantoms)


def clear(view: sublime.View):
    ps = _sets.pop(view.id(), None)
    if ps:
        ps.update([])


def _flatten(nodes: List[finder.TestNode], result: List[finder.TestNode]):
    for node in nodes:
        result.append(node)
        if node.children:
            _flatten(node.children, result)


def _on_navigate(view: sublime.View, href: str):
    w = view.window()
    if not w:
        return
    parts = href.split('|', 3)
    scheme = parts[0]
    if scheme == 'run':
        f = parts[1] if len(parts) > 1 and parts[1] else None
        w.run_command('rust_test_run', {'filter': f})
    elif scheme == 'toggle':
        _, fpath, line_str, ignored_str = parts
        w.run_command('rust_test_toggle_ignore', {
            'file': fpath,
            'fn_line': int(line_str),
            'has_ignore': ignored_str == '1',
        })
