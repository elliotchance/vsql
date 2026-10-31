# The "vsql app" command and the files it can open, and the requests the web
# server answers.

from conftest import app_error


def test_duplicate_catalog(make_file):
    # The catalog names must be unique.
    other_file = make_file('other.vsql', 'CREATE TABLE t (x INT);')
    assert 'there is already a catalog named "other"' in app_error(other_file, other_file)


def test_memory(db_file):
    # Each request opens the files again, so an in-memory database can't be
    # used.
    for args in [[':memory:'], [db_file, ':memory:']]:
        assert ':memory:: an in-memory database is not supported, use a file' in app_error(*args)


def test_not_found(ui):
    assert ui.page.request.get(ui.app.url + 'nope').status == 404
