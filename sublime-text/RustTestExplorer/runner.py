"""
Runs `cargo test` as a background subprocess and streams output line by line.
"""
import os
import subprocess
import threading
from typing import Callable, Optional


def find_cargo_root(start: str) -> Optional[str]:
    """Walk up from `start` until Cargo.toml is found."""
    path = os.path.abspath(start) if not os.path.isdir(start) else start
    while True:
        if os.path.isfile(os.path.join(path, 'Cargo.toml')):
            return path
        parent = os.path.dirname(path)
        if parent == path:
            return None
        path = parent


def _enriched_env() -> dict:
    """Return an environment that includes ~/.cargo/bin so cargo is findable
    when Sublime Text is launched from the GUI (no shell PATH)."""
    env = os.environ.copy()
    brew = env.get('HOMEBREW_PREFIX', '/opt/homebrew')
    extra = [
        os.path.expanduser('~/.cargo/bin'),
        f'{brew}/bin',
        '/usr/local/bin',
    ]
    env['PATH'] = os.pathsep.join(extra + [env.get('PATH', '')])
    return env


class TestRun:
    def __init__(
        self,
        cwd: str,
        filter_arg: Optional[str] = None,
        on_output: Optional[Callable[[str], None]] = None,
        on_done: Optional[Callable[[int], None]] = None,
    ):
        self.cwd = cwd
        self.filter_arg = filter_arg
        self.on_output = on_output or (lambda _: None)
        self.on_done   = on_done   or (lambda _: None)
        self._proc: Optional[subprocess.Popen] = None

    def start(self):
        cmd = ['cargo', 'test']
        if self.filter_arg:
            cmd.append(self.filter_arg)
        cmd += ['--', '--nocapture']
        self._proc = subprocess.Popen(
            cmd,
            cwd=self.cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=_enriched_env(),
        )
        threading.Thread(target=self._stream, daemon=True).start()

    def _stream(self):
        for line in self._proc.stdout:
            self.on_output(line)
        self.on_done(self._proc.wait())

    def cancel(self):
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
