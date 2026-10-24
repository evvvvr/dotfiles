"""
Commands and event listeners for RustTestExplorer.
"""
from __future__ import annotations

import re
import sublime
import sublime_plugin
from typing import Dict, List, Optional

from . import explorer, finder, phantoms, runner, status_store


_active_runs: Dict[int, runner.TestRun] = {}
_pending_redraw: Dict[int, bool]        = {}   # debounce flag per window

_IGNORE_LINE = re.compile(r'^\s*#\[ignore\b')
_ATTR_LINE   = re.compile(r'^\s*#\[')


# ------------------------------------------------------------------ #
# Status refresh helpers
# ------------------------------------------------------------------ #

def _schedule_redraw(window_id: int):
    """Debounced status refresh: coalesces rapid result lines into one repaint."""
    if _pending_redraw.get(window_id):
        return
    _pending_redraw[window_id] = True
    sublime.set_timeout(lambda: _do_redraw(window_id), 120)


def _do_redraw(window_id: int):
    _pending_redraw.pop(window_id, None)
    w = next((w for w in sublime.windows() if w.id() == window_id), None)
    if not w:
        return
    ev = explorer.ExplorerView._instances.get(window_id)
    if ev:
        ev.redraw_status()
    for v in w.views():
        if v.file_name() and v.file_name().endswith('.rs'):
            phantoms.redraw_status(v)


# ------------------------------------------------------------------ #
# Commands
# ------------------------------------------------------------------ #

class RustTestOpenExplorerCommand(sublime_plugin.WindowCommand):
    def run(self):
        explorer.ExplorerView.for_window(self.window).show()


class RustTestRefreshCommand(sublime_plugin.WindowCommand):
    def run(self):
        ev = explorer.ExplorerView._instances.get(self.window.id())
        if ev:
            ev.refresh()


class RustTestRunCommand(sublime_plugin.WindowCommand):
    def run(self, filter: Optional[str] = None):
        ev   = explorer.ExplorerView.for_window(self.window)
        root = ev._get_cargo_root()
        if not root:
            sublime.error_message('RustTestExplorer: no Cargo.toml found.')
            return

        # Cancel any in-flight run
        prev = _active_runs.get(self.window.id())
        if prev:
            prev.cancel()

        # Collect all known cargo filters for status tracking
        all_filters: List[str] = []
        for _, nodes in ev._scan:
            all_filters.extend(finder.collect_cargo_filters(nodes))

        status_store.start_run(self.window.id(), filter, all_filters)
        _schedule_redraw(self.window.id())

        panel  = self._prepare_panel(filter, root)
        wid    = self.window.id()

        def on_output(text: str):
            # Parse result lines and update status store
            result = status_store.parse_line(wid, text)
            if result:
                _schedule_redraw(wid)
            sublime.set_timeout(lambda: panel.run_command('append', {
                'characters': text, 'force': True, 'scroll_to_end': True,
            }), 0)

        def on_done(rc: int):
            _active_runs.pop(wid, None)
            msg = '\n✓ All tests passed\n' if rc == 0 else f'\n✗ Tests failed (exit {rc})\n'
            sublime.set_timeout(lambda: panel.run_command('append', {
                'characters': msg, 'force': True, 'scroll_to_end': True,
            }), 0)
            # Final redraw to clear any lingering RUNNING badges
            sublime.set_timeout(lambda: _do_redraw(wid), 150)

        run = runner.TestRun(
            cwd=root, filter_arg=filter, on_output=on_output, on_done=on_done,
        )
        _active_runs[wid] = run
        run.start()

    def _prepare_panel(self, filter_arg: Optional[str], root: str) -> sublime.View:
        panel = self.window.create_output_panel('rust_tests')
        panel.settings().set('word_wrap', False)
        panel.set_read_only(False)
        panel.run_command('select_all')
        panel.run_command('right_delete')
        label = f'cargo test {filter_arg}' if filter_arg else 'cargo test'
        panel.run_command('append', {
            'characters': f'  {root}\n$ {label}\n\n', 'force': True,
        })
        panel.set_read_only(True)
        self.window.run_command('show_panel', {'panel': 'output.rust_tests'})
        return panel


class RustTestRunAtCursorCommand(sublime_plugin.WindowCommand):
    """Run the test function whose declaration is closest above the cursor."""

    def run(self):
        view = self.window.active_view()
        if not view or not view.file_name() or not view.file_name().endswith('.rs'):
            sublime.status_message('RustTestExplorer: not a Rust file')
            return

        cursor_row = view.rowcol(view.sel()[0].begin())[0]
        all_nodes  = finder.find_tests(
            view.substr(sublime.Region(0, view.size())), view.file_name()
        )
        flat: List[finder.TestNode] = []
        _flatten_all(all_nodes, flat)

        # Nearest test fn at or before cursor
        best: Optional[finder.TestNode] = None
        for node in flat:
            if not node.is_suite and node.line <= cursor_row:
                if best is None or node.line > best.line:
                    best = node

        if best is None:
            sublime.status_message('RustTestExplorer: no test found at or above cursor')
            return

        sublime.status_message(f'RustTestExplorer: running {best.cargo_filter}')
        self.window.run_command('rust_test_run', {'filter': best.cargo_filter})

    def is_enabled(self):
        v = self.window.active_view()
        return bool(v and v.file_name() and v.file_name().endswith('.rs'))


class RustTestRerunLastCommand(sublime_plugin.WindowCommand):
    """Re-run whatever `cargo test` invocation was last used."""

    def run(self):
        if not status_store.has_last(self.window.id()):
            sublime.status_message('RustTestExplorer: no previous test run')
            return
        f = status_store.get_last(self.window.id())
        self.window.run_command('rust_test_run', {'filter': f})

    def is_enabled(self):
        return status_store.has_last(self.window.id())


class RustTestToggleIgnoreCommand(sublime_plugin.WindowCommand):
    def run(self, file: str, fn_line: int, has_ignore: bool):
        view = self.window.open_file(file)
        args = {'fn_line': fn_line, 'has_ignore': has_ignore}
        if view.is_loading():
            sublime.set_timeout(lambda: self._when_loaded(view, args), 50)
        else:
            view.run_command('rust_test_toggle_ignore_internal', args)

    def _when_loaded(self, view: sublime.View, args: dict, attempts: int = 0):
        if view.is_loading() and attempts < 40:
            sublime.set_timeout(lambda: self._when_loaded(view, args, attempts + 1), 50)
        else:
            view.run_command('rust_test_toggle_ignore_internal', args)


class RustTestToggleIgnoreInternalCommand(sublime_plugin.TextCommand):
    def run(self, edit: sublime.Edit, fn_line: int, has_ignore: bool):
        if has_ignore:
            self._remove_ignore(edit, fn_line)
        else:
            self._add_ignore(edit, fn_line)
        view = self.view
        sublime.set_timeout(lambda: phantoms.update(view), 10)
        w = view.window()
        if w:
            ev = explorer.ExplorerView._instances.get(w.id())
            if ev:
                sublime.set_timeout(ev.refresh, 10)

    def _remove_ignore(self, edit: sublime.Edit, fn_line: int):
        view = self.view
        for row in range(fn_line - 1, max(fn_line - 8, -1), -1):
            region = view.line(view.text_point(row, 0))
            if _IGNORE_LINE.match(view.substr(region)):
                erase = sublime.Region(region.begin(), region.end() + 1)
                if erase.end() > view.size():
                    erase = sublime.Region(region.begin() - 1, region.end())
                view.erase(edit, erase)
                return

    def _add_ignore(self, edit: sublime.Edit, fn_line: int):
        view    = self.view
        fn_text = view.substr(view.line(view.text_point(fn_line, 0)))
        spaces  = fn_text[:len(fn_text) - len(fn_text.lstrip())]
        attr_start = fn_line
        for row in range(fn_line - 1, max(fn_line - 10, -1), -1):
            if _ATTR_LINE.match(view.substr(view.line(view.text_point(row, 0))).strip()):
                attr_start = row
            else:
                break
        view.insert(edit, view.text_point(attr_start, 0), f'{spaces}#[ignore]\n')


# ------------------------------------------------------------------ #
# Event listener
# ------------------------------------------------------------------ #

class RustTestEventListener(sublime_plugin.EventListener):
    def on_load_async(self, view: sublime.View):
        phantoms.update(view)

    def on_post_save_async(self, view: sublime.View):
        phantoms.update(view)
        w = view.window()
        if w:
            ev = explorer.ExplorerView._instances.get(w.id())
            if ev:
                ev.refresh()

    def on_close(self, view: sublime.View):
        phantoms.clear(view)
        if view.settings().get('rust_test_explorer'):
            w   = view.window()
            wid = w.id() if w else None
            if wid and wid in explorer.ExplorerView._instances:
                del explorer.ExplorerView._instances[wid]


# ------------------------------------------------------------------ #
# Helpers
# ------------------------------------------------------------------ #

def _flatten_all(nodes: List[finder.TestNode], result: List[finder.TestNode]):
    for node in nodes:
        result.append(node)
        if node.children:
            _flatten_all(node.children, result)
