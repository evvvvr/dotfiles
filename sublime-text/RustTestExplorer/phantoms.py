"""
Inline ▶ phantoms injected next to #[test] fn declarations in open .rs files.
"""
from __future__ import annotations

import sublime
from typing import Dict, List

from . import finder

BTN_STYLE = (
    'color: var(--greenish, #4ec9b0); '
    'text-decoration: none; '
    'padding: 0 2px;'
)

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
        line_end = view.line(view.text_point(node.line, 0)).end()
        icon     = '▶▶' if node.is_suite else '▶'
        action   = f'run:{node.cargo_filter}'
        html     = f'<body><a href="{action}" style="{BTN_STYLE}"> {icon}</a></body>'
        phantoms.append(sublime.Phantom(
            sublime.Region(line_end),
            html,
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
    if href.startswith('run:'):
        w = view.window()
        if w:
            w.run_command('rust_test_run', {'filter': href[4:]})
