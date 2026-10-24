"""
Commands and event listeners for RustTestExplorer.
"""
from __future__ import annotations

import re
import sublime
import sublime_plugin
from typing import Dict, Optional

from . import explorer, phantoms, runner


_active_runs: Dict[int, runner.TestRun] = {}  # window.id() → TestRun

_IGNORE_LINE = re.compile(r'^\s*#\[ignore\b')
_ATTR_LINE   = re.compile(r'^\s*#\[')


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

        prev = _active_runs.get(self.window.id())
        if prev:
            prev.cancel()

        panel = self._prepare_panel(filter, root)

        def on_output(text: str):
            sublime.set_timeout(lambda: panel.run_command('append', {
                'characters': text, 'force': True, 'scroll_to_end': True,
            }), 0)

        def on_done(rc: int):
            _active_runs.pop(self.window.id(), None)
            msg = '\n✓ All tests passed\n' if rc == 0 else f'\n✗ Tests failed (exit {rc})\n'
            sublime.set_timeout(lambda: panel.run_command('append', {
                'characters': msg, 'force': True, 'scroll_to_end': True,
            }), 0)

        run = runner.TestRun(
            cwd=root, filter_arg=filter, on_output=on_output, on_done=on_done,
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
            'characters': f'  {root}\n$ {label}\n\n', 'force': True,
        })
        panel.set_read_only(True)
        self.window.run_command('show_panel', {'panel': 'output.rust_tests'})
        return panel


class RustTestToggleIgnoreCommand(sublime_plugin.WindowCommand):
    """Opens the file (if needed) and delegates the edit to the TextCommand below."""

    def run(self, file: str, fn_line: int, has_ignore: bool):
        view = self.window.open_file(file)
        args = {'fn_line': fn_line, 'has_ignore': has_ignore}
        if view.is_loading():
            # Poll until loaded, then edit
            sublime.set_timeout(lambda: self._when_loaded(view, args), 50)
        else:
            view.run_command('rust_test_toggle_ignore_internal', args)

    def _when_loaded(self, view: sublime.View, args: dict, attempts: int = 0):
        if view.is_loading() and attempts < 40:
            sublime.set_timeout(
                lambda: self._when_loaded(view, args, attempts + 1), 50
            )
        else:
            view.run_command('rust_test_toggle_ignore_internal', args)


class RustTestToggleIgnoreInternalCommand(sublime_plugin.TextCommand):
    """TextCommand that performs the actual buffer edit."""

    def run(self, edit: sublime.Edit, fn_line: int, has_ignore: bool):
        view = self.view
        if has_ignore:
            self._remove_ignore(view, edit, fn_line)
        else:
            self._add_ignore(view, edit, fn_line)

        # Refresh phantoms on this view and the explorer
        sublime.set_timeout(lambda: phantoms.update(view), 10)
        w = view.window()
        if w:
            ev = explorer.ExplorerView._instances.get(w.id())
            if ev:
                sublime.set_timeout(ev.refresh, 10)

    # -- helpers --

    def _remove_ignore(self, view: sublime.View, edit: sublime.Edit, fn_line: int):
        for row in range(fn_line - 1, max(fn_line - 8, -1), -1):
            region = view.line(view.text_point(row, 0))
            if _IGNORE_LINE.match(view.substr(region)):
                # Erase the line + its newline
                erase = sublime.Region(region.begin(), region.end() + 1)
                if erase.end() > view.size():
                    erase = sublime.Region(region.begin() - 1, region.end())
                view.erase(edit, erase)
                return

    def _add_ignore(self, view: sublime.View, edit: sublime.Edit, fn_line: int):
        # Find the indentation from the fn line
        fn_text = view.substr(view.line(view.text_point(fn_line, 0)))
        indent  = len(fn_text) - len(fn_text.lstrip())
        spaces  = fn_text[:indent]

        # Walk back to find the top of the attribute block
        attr_start = fn_line
        for row in range(fn_line - 1, max(fn_line - 10, -1), -1):
            line_text = view.substr(view.line(view.text_point(row, 0))).strip()
            if _ATTR_LINE.match(line_text):
                attr_start = row
            else:
                break  # hit a non-attribute line (e.g. blank, comment, code)

        insert_pos = view.text_point(attr_start, 0)
        view.insert(edit, insert_pos, f'{spaces}#[ignore]\n')


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
            w = view.window()
            wid = w.id() if w else None
            if wid and wid in explorer.ExplorerView._instances:
                del explorer.ExplorerView._instances[wid]
