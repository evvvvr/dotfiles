"""
Rust test discovery via line-by-line scanning.
Handles #[test], #[tokio::test], #[async_std::test] and #[cfg(test)] modules.
Note: brace counting ignores string literals — good enough for test code.
"""
import os
import re
from dataclasses import dataclass, field
from typing import List, Tuple

@dataclass
class TestNode:
    name: str
    cargo_filter: str   # substring passed to `cargo test <filter>`
    file: str           # absolute path
    line: int           # 0-indexed line of the fn / mod declaration
    is_suite: bool      # True = mod, False = fn
    children: 'List[TestNode]' = field(default_factory=list)
    ignored: bool = False


_TEST_ATTR   = re.compile(r'^\s*#\[(?:(?:tokio|async_std)::)?test\b')
_IGNORE_ATTR = re.compile(r'^\s*#\[ignore\b')
_CFG_TEST    = re.compile(r'^\s*#\[cfg\(test\)\]')
_FN_DECL     = re.compile(r'\bfn\s+(\w+)\s*[<(]')
_MOD_DECL    = re.compile(r'\bmod\s+(\w+)\s*\{')


def find_tests(content: str, filepath: str) -> List[TestNode]:
    lines = content.splitlines()
    root: List[TestNode] = []
    # stack entries: [name, prefix, children_list, entry_depth]
    stack: List[list] = []
    depth = 0
    pending_test   = False
    pending_suite  = False
    pending_ignore = False

    def cur_children() -> List[TestNode]:
        return stack[-1][2] if stack else root

    def cur_prefix() -> str:
        return '::'.join(s[0] for s in stack)

    for lineno, raw in enumerate(lines):
        # Strip line comments before brace counting
        code = raw.split('//')[0]
        opens  = code.count('{')
        closes = code.count('}')

        if _TEST_ATTR.match(raw):
            pending_test = True
        if _IGNORE_ATTR.match(raw):
            pending_ignore = True
        if _CFG_TEST.match(raw):
            pending_suite = True

        fn_match = _FN_DECL.search(code)

        if pending_test and fn_match:
            name = fn_match.group(1)
            prefix = cur_prefix()
            cargo = f'{prefix}::{name}' if prefix else name
            cur_children().append(
                TestNode(name, cargo, filepath, lineno, False, ignored=pending_ignore)
            )
            pending_test   = False
            pending_ignore = False
        elif fn_match:
            # Non-test fn: discard any stray #[ignore] that isn't for a test
            pending_ignore = False

        if pending_suite:
            m = _MOD_DECL.search(code)
            if m:
                name = m.group(1)
                prefix = cur_prefix()
                cargo = f'{prefix}::{name}' if prefix else name
                children: List[TestNode] = []
                cur_children().append(TestNode(name, cargo, filepath, lineno, True, children))
                stack.append([name, cargo, children, depth])
                pending_suite = False

        depth += opens - closes

        while stack and depth <= stack[-1][3]:
            stack.pop()

    return root


def scan_project(root_dir: str) -> List[Tuple[str, List[TestNode]]]:
    """Walk a Cargo project and return (relative_path, tests) for every .rs file that has tests."""
    results = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Skip build output
        dirnames[:] = [d for d in dirnames if d != 'target']
        for fname in sorted(filenames):
            if not fname.endswith('.rs'):
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, encoding='utf-8', errors='ignore') as f:
                    content = f.read()
            except OSError:
                continue
            tests = find_tests(content, fpath)
            if tests:
                results.append((os.path.relpath(fpath, root_dir), tests))
    return results
