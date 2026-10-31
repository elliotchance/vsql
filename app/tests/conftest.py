# The fixtures for the "vsql app" tests (see docs/testing.rst), to set up the
# files and start the app. Finding things on the page is in pages.py. VSQL is
# the vsql binary to test, like the CLI tests. It's made absolute, since an app
# can be started in another directory.

import os
import re
import socket
import subprocess
import time
import urllib.error
import urllib.request

import pytest

from pages import AppPage

VSQL = os.path.abspath(os.environ.get('VSQL', 'bin/vsql'))

# setup_sql is the tables in db.vsql, a table with a name that must be escaped
# (and values that must be escaped) and a table in another schema.
setup_sql = '''
CREATE TABLE "my <t>" (x INT, s VARCHAR(10));
INSERT INTO "my <t>" (x, s) VALUES (1, 'a&b'), (NULL, NULL);
CREATE SCHEMA foo;
CREATE TABLE foo.bar (y BOOLEAN);
'''


def run_vsql(*args, sql=''):
    """run_vsql runs a vsql command with the SQL on stdin, and returns what it
    printed. It must succeed."""
    result = subprocess.run([VSQL, *args], input=sql, capture_output=True,
                            text=True, timeout=60)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def cli(path, sql):
    """cli runs SQL on a file with "vsql cli" and returns the output."""
    return run_vsql('cli', str(path), sql=sql)


def count(path, sql):
    """count is the only value returned by SQL, such as a COUNT(*)."""
    return int(re.search(r'^ *(\d+) *$', cli(path, sql), re.MULTILINE).group(1))


def app_error(*args):
    """app_error is what "vsql app" printed when it couldn't start."""
    result = subprocess.run([VSQL, 'app', *map(str, args)], capture_output=True,
                            text=True, timeout=60)
    assert result.returncode != 0
    return result.stdout + result.stderr


@pytest.fixture
def make_file(tmp_path):
    """make_file creates a file (in its own directory, since the catalog is
    named after the file) with "vsql in" and returns its path."""

    def make(name, sql):
        directory = tmp_path / str(len(list(tmp_path.iterdir())))
        directory.mkdir()
        path = directory / name
        run_vsql('in', str(path), sql=sql)
        return path

    return make


@pytest.fixture
def db_file(make_file):
    """db_file is db.vsql (the catalog "db") with setup_sql."""
    return make_file('db.vsql', setup_sql)


def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


class App:
    """App is a running "vsql app"."""

    def __init__(self, *paths, cwd=None):
        port = free_port()
        self.url = f'http://127.0.0.1:{port}/'
        self.process = subprocess.Popen(
            [VSQL, 'app', '-p', str(port), *map(str, paths)], cwd=cwd,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        output = ''
        for line in self.process.stdout:
            output += line
            if line.startswith('ready on '):
                break
        else:
            raise AssertionError(f'vsql app exited: {output}')

        # VSQL_APP is created after "ready on" is printed, so wait for the
        # first page.
        deadline = time.monotonic() + 10
        while True:
            try:
                urllib.request.urlopen(self.url, timeout=5).read()
                break
            except urllib.error.URLError:
                if time.monotonic() > deadline:
                    raise
                time.sleep(0.1)

    def stop(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=10)
        self.process.stdout.close()


@pytest.fixture
def start_app():
    """start_app starts "vsql app" with files (the first is the current
    catalog) in the cwd directory, and returns an App. It's stopped at the end
    of the test, or with stop() to start it again."""
    apps = []

    def start(*paths, cwd=None):
        app = App(*paths, cwd=cwd)
        apps.append(app)
        return app

    yield start
    for app in apps:
        app.stop()


@pytest.fixture
def ui(page, db_file, start_app):
    """ui is the page of an app started with db_file. ui.app is the App."""
    return AppPage(page, start_app(db_file))
