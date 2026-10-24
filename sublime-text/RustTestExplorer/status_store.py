"""
Per-window test status store and last-filter memory.
Parses `cargo test` output lines to track pass/fail/skip per test.
"""
from __future__ import annotations

import re
from enum import Enum
from typing import Dict, List, Optional, Tuple

class Status(Enum):
    UNKNOWN = 'unknown'
    RUNNING = 'running'
    PASSED  = 'passed'
    FAILED  = 'failed'
    SKIPPED = 'skipped'

# (icon, hex-color) for each status
BADGE: Dict[Status, Tuple[str, str]] = {
    Status.UNKNOWN: ('',  ''),
    Status.RUNNING: ('●', '#e5c07b'),
    Status.PASSED:  ('✓', '#98c379'),
    Status.FAILED:  ('✗', '#e06c75'),
    Status.SKIPPED: ('⊘', '#888888'),
}

_store: Dict[int, Dict[str, Status]] = {}  # window_id → {cargo_path → Status}
_last:  Dict[int, Optional[str]]     = {}  # window_id → last filter (None = all)

_RESULT_RE = re.compile(r'^test (.+) \.\.\. (ok|FAILED|ignored)\s*$')
_STATUS_MAP = {'ok': Status.PASSED, 'FAILED': Status.FAILED, 'ignored': Status.SKIPPED}


def get(window_id: int, cargo_filter: str) -> Status:
    store = _store.get(window_id, {})
    if cargo_filter in store:
        return store[cargo_filter]
    # Cargo output sometimes includes a crate-name prefix — try suffix match
    for path, status in store.items():
        if path == cargo_filter or path.endswith(f'::{cargo_filter}'):
            return status
    return Status.UNKNOWN


def start_run(window_id: int, filter_arg: Optional[str], all_filters: List[str]):
    """Mark matching tests as RUNNING and remember the filter."""
    store = _store.setdefault(window_id, {})
    for f in all_filters:
        if filter_arg is None or filter_arg in f:
            store[f] = Status.RUNNING
    _last[window_id] = filter_arg


def parse_line(window_id: int, line: str) -> Optional[Tuple[str, Status]]:
    """Parse one line of cargo test output; update store if it's a result line."""
    m = _RESULT_RE.match(line.strip())
    if not m:
        return None
    cargo_path = m.group(1)
    status = _STATUS_MAP[m.group(2)]
    _store.setdefault(window_id, {})[cargo_path] = status
    return cargo_path, status


def get_last(window_id: int) -> Optional[str]:
    return _last.get(window_id)


def has_last(window_id: int) -> bool:
    return window_id in _last
