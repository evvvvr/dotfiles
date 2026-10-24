"""
Commands and event listeners for RustTestExplorer.
"""
from __future__ import annotations

import sublime
import sublime_plugin
from typing import Dict, Optional

from . import explorer, phantoms, runner


_active_runs: Dict[int, runner.TestRun] = {}  # window.id() → TestRun


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
        ev    = explorer.ExplorerView.for_window(self.window)
        root  = ev._get_cargo_root()
        if not root:
            sublime.error_message('RustTestExplorer: no Cargo.toml found.')
            return

        # Cancel any in-flight run
        prev = _active_runs.get(self.window.id())
        if prev:
            prev.cancel()

        panel = self._prepare_panel(filter, root)

        def on_output(text: str):
            sublime.set_timeout(
                lambda: panel.run_command('append', {
                    'characters': text, 'force': True, 'scroll_to_end': True,
                }), 0)

        def on_done(rc: int):
            _active_runs.pop(self.window.id(), None)
            msg = '\n✓ All tests passed\n' if rc == 0 else f'\n✗ Tests failed (exit {rc})\n'
            sublime.set_timeout(
                lambda: panel.run_command('append', {
                    'characters': msg, 'force': True, 'scroll_to_end': True,
                }), 0)

        run = runner.TestRun(
            cwd=root,
            filter_arg=filter,
            on_output=on_output,
            on_done=on_done,
        )
        _active_runs[self.window.id()] = run
        run.start()

    def _prepare_panel(self, filter_arg, root: str) -> sublime.View:
        panel = self.window.create_output_panel('rust_tests')
        panel.settings().set('word_wrap', False)
        panel.set_read_only(False)
        panel.run_command('select_all')
        panel.run_command('right_delete')
        label = f'cargo test {filter_arg}' if filter_arg else 'cargo test'
        panel.run_command('append', {
            'characters': f'  {root}\n$ {label}\n\n',
            'force': True,
        })
        panel.set_read_only(True)
        self.window.run_command('show_panel', {'panel': 'output.rust_tests'})
        return panel


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
        # If the explorer view itself was closed, drop the instance
        if view.settings().get('rust_test_explorer'):
            wid = view.window().id() if view.window() else None
            if wid and wid in explorer.ExplorerView._instances:
                del explorer.ExplorerView._instances[wid]
