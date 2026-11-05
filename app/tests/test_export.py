# The EXPORT tab, which is opened from the menu of a file, schema or table, or from
# a query. The command that's shown must give the same output as the download.

import os
import re
import shutil
import subprocess
import tempfile

from playwright.sync_api import expect

from conftest import cli, count


def run_command(command):
    """run_command runs the command as it's shown in a shell (with vsql on the
    PATH) in a new folder, and returns the name and text of the only file it
    wrote."""
    cwd = tempfile.mkdtemp()
    bin_dir = os.path.dirname(os.path.abspath(os.environ['VSQL']))
    env = {**os.environ, 'PATH': f'{bin_dir}{os.pathsep}{os.environ["PATH"]}'}
    subprocess.run(['sh', '-c', command], cwd=cwd, env=env, check=True)
    files = os.listdir(cwd)
    assert len(files) == 1
    with open(os.path.join(cwd, files[0]), newline='') as f:
        text = f.read()
    shutil.rmtree(cwd)
    return files[0], text


def export_button(ui):
    return ui.page.locator('.export').get_by_role('button', name='Export', exact=True)


def assert_same(ui):
    """assert_same checks that the download and the command give the same file,
    and returns its name and text."""
    downloaded = ui.download(export_button(ui))
    assert run_command(ui.export_command.text_content()) == downloaded
    return downloaded


def test_export_file(ui, db_file, make_file):
    # All of a file is exported as SQL, without the tabs and history of the app,
    # and it can be loaded into another file.
    cli(db_file, 'INSERT INTO foo.bar (y) VALUES (TRUE);')
    ui.catalog_menu('db').get_by_role('button', name='Export').click()
    expect(ui.export_command).to_contain_text("-exclude 'VSQL_APP.*'")
    expect(ui.export_command).to_contain_text(f' {os.path.realpath(db_file)}')
    expect(ui.page.locator('.export [name="export_format"]')).to_have_count(1)
    filename, text = assert_same(ui)
    assert re.fullmatch(r'db-\d{4}-\d\d-\d\d \d\d-\d\d-\d\d\.sql', filename)
    assert 'VSQL_APP' not in text
    assert text.startswith('START TRANSACTION;')
    assert text.endswith('COMMIT;\n')
    other_file = make_file('other.vsql', text)
    assert count(other_file, 'SELECT COUNT(*) FROM foo.bar WHERE y;') == 1


def test_export_file_one_schema(ui, make_file, start_app):
    # Leaving out VSQL_APP is the same length as including the only schema, but
    # it's what the file needs.
    ui.open(start_app(make_file('db.vsql', 'CREATE TABLE t (x INT);')))
    ui.catalog_menu('db').get_by_role('button', name='Export').click()
    expect(ui.export_command).to_contain_text("-exclude 'VSQL_APP.*'")
    expect(ui.export_command).not_to_contain_text('-include')
    _, text = assert_same(ui)
    assert 'CREATE TABLE "PUBLIC"."T"' in text
    assert 'VSQL_APP' not in text


def test_export_schema(ui, db_file):
    # A schema is one pattern.
    cli(db_file, 'INSERT INTO foo.bar (y) VALUES (TRUE);')
    ui.schema_menu('db', 'FOO').get_by_role('button', name='Export').click()
    expect(ui.export_command).to_contain_text("-include 'FOO.*'")
    _, text = assert_same(ui)
    assert 'CREATE TABLE "FOO"."BAR"' in text
    assert 'VSQL_APP' not in text


def test_export_table_formats(ui, db_file):
    # A table is exported as SQL, or with a query for the other formats. The
    # extension of the file name follows the format.
    cli(db_file, "INSERT INTO foo.bar (y) VALUES (TRUE);")
    ui.table_menu('BAR', schema='FOO').get_by_role('button', name='Export').click()
    expect(ui.export_command).to_contain_text('-include FOO.BAR')
    filename, text = assert_same(ui)
    assert filename.endswith('.sql')
    assert 'INSERT INTO "FOO"."BAR" ("Y") VALUES (TRUE);' in text

    ui.export_check('CSV')
    expect(ui.export_command).to_contain_text('-format csv')
    expect(ui.export_command).to_contain_text('-query')
    expect(ui.page.locator('.export-objects')).to_be_hidden()
    filename, text = assert_same(ui)
    assert filename.endswith('.csv')
    assert text == 'Y\r\nTRUE\r\n'

    ui.export_check('No header')
    ui.export_check('TSV')
    expect(ui.export_command).to_contain_text('-no-header')
    filename, text = assert_same(ui)
    assert filename.endswith('.tsv')
    assert text == 'TRUE\n'

    ui.export_check('JSON')
    expect(ui.export_command).not_to_contain_text('-no-header')
    filename, text = assert_same(ui)
    assert filename.endswith('.json')
    assert text == '[\n  {\n    "Y": true\n  }\n]\n'


def test_export_objects(ui, db_file):
    # The options of SQL change the command, with whichever of -include and
    # -exclude is shorter.
    cli(db_file, """CREATE SEQUENCE foo.s;
CREATE TABLE foo.parent (id INT NOT NULL PRIMARY KEY);
CREATE TABLE foo.child (pid INT, CONSTRAINT fk1 FOREIGN KEY (pid) REFERENCES foo.parent (id));""")
    ui.schema_menu('db', 'FOO').get_by_role('button', name='Export').click()
    ui.update_export(lambda: ui.page.locator('.export [value="FOO.FK1"]').uncheck())
    expect(ui.export_command).to_contain_text('-exclude FOO.FK1')
    _, text = assert_same(ui)
    assert 'FK1' not in text
    ui.export_check('No transaction')
    ui.export_check('Create the PUBLIC schema')
    expect(ui.export_command).to_contain_text('-no-transaction -create-public-schema')
    _, text = assert_same(ui)
    assert 'TRANSACTION' not in text
    assert 'CREATE SCHEMA "PUBLIC"' not in text or 'FOO' in text


def test_export_no_schema(ui, db_file):
    # The schema is left out of every name, which can't be with the PUBLIC schema.
    cli(db_file, 'CREATE TABLE foo.items (id INT);\nINSERT INTO foo.items (id) VALUES (1);')
    ui.reload()
    ui.schema_menu('db', 'FOO').get_by_role('button', name='Export').click()
    ui.export_check('Create the PUBLIC schema')
    ui.export_check('No schema names')
    expect(ui.export_command).to_contain_text('-no-schema')
    expect(ui.export_command).not_to_contain_text('-create-public-schema')
    expect(ui.export_option('Create the PUBLIC schema')).to_be_disabled()
    _, text = assert_same(ui)
    assert 'CREATE TABLE "ITEMS"' in text
    assert 'INSERT INTO "ITEMS"' in text
    assert 'SCHEMA' not in text

    ui.export_check('No schema names', False)
    expect(ui.export_command).not_to_contain_text('-no-schema')
    expect(ui.export_option('Create the PUBLIC schema')).to_be_enabled()

    # It's kept on the tab, and it's for another database too.
    ui.export_check('No schema names')
    ui.update_export(lambda: ui.export_option('Compatible with').select_option('postgresql'))
    expect(ui.export_command).to_contain_text('-no-schema -compat postgresql')
    _, text = assert_same(ui)
    assert 'CREATE TABLE "items"' in text
    ui.reload()
    expect(ui.export_option('No schema names')).to_be_checked()


def test_export_compat(ui, db_file):
    # The command for another database, and what's in it, is the same as the
    # download. Only vsql can have the PUBLIC schema created.
    cli(db_file, 'CREATE TABLE foo (id INT);\nINSERT INTO foo (id) VALUES (1);')
    ui.reload()
    ui.table_menu('FOO').get_by_role('button', name='Export').click()
    ui.export_check('Create the PUBLIC schema')
    expect(ui.export_command).to_contain_text('-create-public-schema')

    expect(ui.export_option('Compatible with').locator('option')).to_have_text(['vsql', 'sqlite3', 'mysql', 'postgresql'])
    ui.update_export(lambda: ui.export_option('Compatible with').select_option('sqlite3'))
    expect(ui.export_command).to_contain_text('-compat sqlite3')
    expect(ui.export_command).not_to_contain_text('-create-public-schema')
    expect(ui.export_option('Create the PUBLIC schema')).to_be_disabled()
    _, text = assert_same(ui)
    assert 'BEGIN TRANSACTION;' in text
    assert 'CREATE TABLE "foo"' in text

    ui.update_export(lambda: ui.export_option('Compatible with').select_option('postgresql'))
    expect(ui.export_command).to_contain_text('-compat postgresql')
    ui.update_export(lambda: ui.export_option('Contents').select_option('Schema only'))
    expect(ui.export_command).to_contain_text('-compat postgresql -schema-only')
    _, text = assert_same(ui)
    assert 'CREATE TABLE "foo"' in text
    assert 'INSERT' not in text

    ui.update_export(lambda: ui.export_option('Contents').select_option('Data only'))
    expect(ui.export_command).to_contain_text('-data-only')
    _, text = assert_same(ui)
    assert 'CREATE TABLE' not in text
    assert 'INSERT INTO "foo"' in text

    ui.update_export(lambda: ui.export_option('Compatible with').select_option('vsql'))
    expect(ui.export_option('Create the PUBLIC schema')).to_be_enabled()
    expect(ui.export_command).not_to_contain_text('-compat')


def test_export_saved_as_you_type(ui, db_file):
    # The options are kept without anything else being posted, even if they're
    # changed faster than the server can answer.
    ui.schema_menu('db', 'FOO').get_by_role('button', name='Export').click()
    ui.export_option('File name').fill('')
    ui.export_option('File name').press_sequentially('mine-typed-quickly.sql')
    expect(ui.export_command).to_contain_text('-file mine-typed-quickly.sql')
    ui.export_check('No transaction')
    ui.update_export(lambda: ui.export_option('Compatible with').select_option('mysql'))
    ui.update_export(lambda: ui.export_option('Contents').select_option('Schema only'))
    command = ui.export_command.text_content()

    ui.reload()
    expect(ui.export_command).to_have_text(command)
    expect(ui.export_option('File name')).to_have_value('mine-typed-quickly.sql')
    expect(ui.export_option('No transaction')).to_be_checked()
    expect(ui.export_option('Compatible with')).to_have_value('mysql')
    expect(ui.export_option('Contents')).to_have_value('schema-only')

    # And going to another tab and back, which posts the form.
    ui.new_tab()
    ui.tab('Export FOO').click()
    expect(ui.export_command).to_have_text(command)


def test_export_query_saved_as_you_type(ui, db_file):
    ui.table_menu('BAR', schema='FOO').get_by_role('button', name='Export').click()
    ui.export_check('CSV')
    ui.export_set('Query', 'SELECT * FROM foo.bar WHERE y = ?')
    ui.export_set('P1', 'hello')
    command = ui.export_command.text_content()
    assert 'P1=hello' in command

    ui.reload()
    expect(ui.export_command).to_have_text(command)
    expect(ui.export_option('CSV')).to_be_checked()
    expect(ui.export_option('Query')).to_have_value('SELECT * FROM foo.bar WHERE y = ?')
    expect(ui.export_option('P1')).to_have_value('hello')


def test_export_file_name(ui, db_file):
    # The file name can be changed, it's quoted in the command and names the
    # download.
    ui.schema_menu('db', 'FOO').get_by_role('button', name='Export').click()
    ui.export_set('File name', "it's mine.sql")
    expect(ui.export_command).to_contain_text("-file 'it'\\''s mine.sql'")
    filename, _ = assert_same(ui)
    assert filename == "it's mine.sql"


def test_export_query(ui, db_file):
    # Export on a query tab uses the last statement. It's run again, not the
    # statements before it.
    cli(db_file, 'INSERT INTO foo.bar (y) VALUES (TRUE);')
    ui.new_tab()
    ui.run('INSERT INTO foo.bar (y) VALUES (FALSE); SELECT * FROM foo.bar WHERE y')
    expect(ui.rows).to_have_count(1)
    ui.page.locator('button.export-query-tab').click()
    expect(ui.export_command).to_contain_text("-query 'SELECT * FROM foo.bar WHERE y'")
    expect(ui.page.locator('.export [name="export_format"]')).to_have_count(3)
    expect(ui.page.locator('.export-objects')).to_be_hidden()
    filename, text = assert_same(ui)
    assert filename.endswith('.csv')
    assert text == 'Y\r\nTRUE\r\n'
    assert count(db_file, 'SELECT COUNT(*) FROM foo.bar;') == 2


def test_export_params(ui, db_file):
    # Each "?" is an environment variable, which is shown before the command. Its
    # value isn't part of the SQL, and \N is NULL.
    cli(db_file, """CREATE TABLE foo.v (x INT, s VARCHAR(10));
INSERT INTO foo.v (x, s) VALUES (1, 'it''s');""")
    ui.new_tab()
    ui.page.locator('textarea[name="sql"]').fill('SELECT x, ? AS n FROM foo.v WHERE s = ?')
    ui.page.locator('button.export-query-tab').click()
    ui.export_set('Query', 'SELECT x, ? AS n FROM foo.v WHERE s = ?')
    ui.update_export(lambda: ui.page.locator('[name="export_param:1"]').fill('\\N'))
    ui.update_export(lambda: ui.page.locator('[name="export_param:2"]').fill("it's"))
    expect(ui.export_command).to_contain_text("P1='\\N' P2='it'\\''s' vsql out")
    _, text = assert_same(ui)
    assert text == 'X,N\r\n1,\r\n'

    ui.export_set('NULL is written as', 'none')
    _, text = assert_same(ui)
    assert text == 'X,N\r\n1,none\r\n'


def test_export_error(ui, db_file):
    # An error from "vsql out" is shown on the tab, and what was chosen is kept.
    ui.new_tab()
    ui.page.locator('textarea[name="sql"]').fill('SELECT * FROM foo.bar')
    ui.page.locator('button.export-query-tab').click()
    ui.export_set('Query', 'SELECT * FROM nope')
    export_button(ui).click()
    expect(ui.page.locator('.export .error')).to_contain_text('no such table')
    expect(ui.page.locator('.export textarea')).to_have_value('SELECT * FROM nope')


def test_export_large(ui, db_file):
    # More output than fits in the buffer of a pipe.
    cli(db_file, 'CREATE TABLE foo.big (s VARCHAR(200));')
    cli(db_file, ("INSERT INTO foo.big (s) VALUES ('" + 'x' * 200 + "');\n") * 601)
    ui.schema_menu('db', 'FOO').get_by_role('button', name='Export').click()
    _, text = assert_same(ui)
    assert text.count('INSERT INTO "FOO"."BIG"') == 601
