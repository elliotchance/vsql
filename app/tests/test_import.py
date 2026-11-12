# Importing a file on an IMPORT tab, opened from the menu of a catalog, schema or
# table. The options depend on the type of the file.

import os
import re
import shlex
import subprocess

import pytest
from playwright.sync_api import expect

from conftest import cli, count


def open_import(menu):
    """open_import opens an IMPORT tab from a menu, and returns the tab."""
    menu.get_by_role('button', name='Import').click()


def choose_file(ui, name, text):
    """choose_file chooses a file on an IMPORT tab, which shows its options."""
    ui.page.locator('.import-file').set_input_files({'name': name, 'mimeType': 'text/plain', 'buffer': text.encode()})


def run_import(ui):
    ui.page.locator('.import-run').click()


def import_sql(ui, name, text, on_error=None):
    open_import(ui.catalog_menu('db'))
    choose_file(ui, name, text)
    if on_error is not None:
        ui.page.locator('[name="import_on_error"]').select_option(on_error)
    expect(ui.page.locator('.import-options')).to_be_visible()
    run_import(ui)


def import_table(ui, name, text, table=None):
    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, name, text)
    expect(ui.page.locator('.import-options')).to_be_visible()
    if table is not None:
        ui.page.locator('[name="import_new"]').fill(table)
    run_import(ui)


def import_rows(ui, table, name, text, schema='FOO', on_error=None):
    open_import(ui.table_menu(table, schema=schema))
    choose_file(ui, name, text)
    expect(ui.page.locator('.import-options')).to_be_visible()
    if on_error is not None:
        ui.page.locator('[name="import_on_error"]').select_option(on_error)
    run_import(ui)


def notice(ui):
    return ui.page.locator('main .notice')


def failures(ui):
    return ui.page.locator('.import-messages .import-error')


def view_table(ui):
    ui.page.locator('.view-table').click()


def command(ui):
    return ui.page.locator('.import-command pre')


def test_import_command(ui, db_file):
    # It's the command of "vsql in", which changes with the options.
    cli(db_file, 'CREATE TABLE foo.p (id INT, name VARCHAR(10));')
    ui.reload()
    open_import(ui.catalog_menu('db'))
    expect(command(ui)).to_be_hidden()
    choose_file(ui, 'load file.sql', 'SELECT 1;')
    path = os.path.realpath(db_file)
    expect(command(ui)).to_have_text(f"vsql in -file 'load file.sql' -single-transaction -isolation read-committed {path}")
    ui.page.locator('[name="import_schema"]').select_option('FOO')
    expect(command(ui)).to_have_text(f"vsql in -file 'load file.sql' -schema FOO -single-transaction -isolation read-committed {path}")
    ui.page.locator('[name="import_on_error"]').select_option('continue')
    ui.page.locator('[name="import_transaction"]').uncheck()
    expect(command(ui)).to_have_text(f"vsql in -file 'load file.sql' -schema FOO -continue-on-error -isolation read-committed {path}")

    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, 'people.csv', 'id,name\n1,a\n')
    expect(command(ui)).to_have_text(f"vsql in -file people.csv -schema FOO -table people -create-table 'ID INTEGER, NAME VARCHAR(255)' -isolation read-committed {path}")
    ui.page.get_by_label('Type of id').fill('BIGINT')
    expect(command(ui)).to_have_text(f"vsql in -file people.csv -schema FOO -table people -create-table 'ID BIGINT, NAME VARCHAR(255)' -isolation read-committed {path}")
    ui.page.get_by_label('Column for name').fill('')
    expect(command(ui)).to_have_text(f"vsql in -file people.csv -schema FOO -table people -create-table 'ID BIGINT' -map id=ID -isolation read-committed {path}")

    open_import(ui.table_menu('P', schema='FOO'))
    choose_file(ui, 'p.csv', 'ID,full\n1,a\n')
    expect(command(ui)).to_have_text(f'vsql in -file p.csv -schema FOO -table P -map ID=ID -isolation read-committed {path}')
    ui.page.get_by_label('Column for full').select_option('NAME')
    expect(command(ui)).to_have_text(f'vsql in -file p.csv -schema FOO -table P -map ID=ID -map full=NAME -isolation read-committed {path}')


def test_import_command_works(ui, db_file, tmp_path):
    # The command that's shown does the same thing from the folder of the file.
    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, 'p.csv', 'a,b\n1,2\n')
    ui.page.get_by_label('Column for a').fill('renamed')
    expect(command(ui)).to_contain_text('-map a=RENAMED')
    words = shlex.split(command(ui).inner_text())
    (tmp_path / 'p.csv').write_text('a,b\n1,2\n')
    subprocess.run([os.path.abspath(os.environ['VSQL']), *words[1:]], cwd=tmp_path, check=True)
    assert count(db_file, 'SELECT renamed FROM foo.p;') == 1


def test_import_one_transaction_off(ui, db_file):
    # What ran before the failure is kept.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'load.sql', 'CREATE TABLE foo.t (x INT);\nINSERT INTO foo.nope (x) VALUES (1);\n')
    ui.page.locator('[name="import_transaction"]').uncheck()
    expect(command(ui)).not_to_contain_text('-single-transaction')
    run_import(ui)
    expect(ui.error).to_have_text('load.sql: 1 statement executed, 1 failed')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.t;') == 0


SQLITE = """PRAGMA foreign_keys = OFF;
DROP TABLE IF EXISTS [Album];
CREATE TABLE [Album] ([AlbumId] INTEGER NOT NULL, [ArtistId] INTEGER, [On] DATETIME,
    CONSTRAINT [PK_Album] PRIMARY KEY ([AlbumId]),
    FOREIGN KEY ([ArtistId]) REFERENCES [Artist] ([ArtistId]));
CREATE TABLE [Artist] ([ArtistId] INTEGER NOT NULL, [Name] NVARCHAR(120),
    CONSTRAINT [PK_Artist] PRIMARY KEY ([ArtistId]));
CREATE INDEX [I] ON [Album] ([ArtistId]);
CREATE INDEX [P] ON [Album] ([On]) WHERE [On] IS NOT NULL;
INSERT INTO [Artist] ([ArtistId], [Name]) VALUES (1, 'a'), (2, 'b');
INSERT INTO [Album] VALUES (1, 1, '2020-01-02 00:00:00');
"""


def test_import_sqlite(ui, db_file):
    # The options of a SQL file are in the command, and what happened is counted.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'sqlite.sql', SQLITE)
    stats = ui.page.locator('.import-stats')
    expect(stats.locator('tr').filter(has_text='CREATE INDEX')).to_have_text('CREATE INDEX~2')
    ui.page.locator('[name="import_compat"]').select_option('sqlite3')
    ui.page.locator('[name="import_ignore_unsupported"]').check()
    expect(command(ui)).to_contain_text('-compat sqlite3 -ignore-unsupported')
    run_import(ui)
    expect(notice(ui)).to_contain_text('1 warning')
    operations = ui.page.locator('.import-operations')
    expect(operations.locator('tr').filter(has_text='CREATE TABLE')).to_have_text('CREATE TABLE2')
    expect(operations.locator('tr').filter(has_text='INSERT')).to_have_text('INSERT3')
    expect(operations.locator('tr').filter(has_text='CREATE INDEX')).to_have_text('CREATE INDEX1')
    # A partial index isn't supported.
    expect(ui.page.locator('.import-warning')).to_contain_text('WARNING 01000 CREATE INDEX failed')
    assert count(db_file, 'SELECT COUNT(*) FROM artist;') == 2


def test_import_unsupported_without_option(ui):
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'sqlite.sql', 'CREATE VIEW v AS SELECT 1;\n')
    run_import(ui)
    expect(failures(ui)).to_contain_text('Line 1')


def big_sql(rows=4000):
    """big_sql takes long enough to do things while it's being imported."""
    inserts = ''.join(f"INSERT INTO foo.big (x, y) VALUES ({i}, 'row {i}');\n" for i in range(rows))
    return 'CREATE TABLE foo.big (x INT, y VARCHAR(20));\n' + inserts


def start_big_import(ui):
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'big.sql', big_sql())
    expect(ui.page.locator('.import-options')).to_be_visible()
    run_import(ui)
    expect(ui.page.locator('.import-cancel')).to_be_visible()


def test_import_messages(ui):
    # Errors, warnings and notices are all shown in order, with their own colors.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'load.sql', """CREATE TABLE foo.t (x INT);
DELETE FROM foo.t WHERE x = 1;
CREATE VIEW v AS SELECT 1;
INSERT INTO foo.nope (x) VALUES (1);
INSERT INTO foo.t (x) VALUES (1);
""")
    ui.page.locator('[name="import_ignore_unsupported"]').check()
    ui.page.locator('[name="import_on_error"]').select_option('continue')
    expect(command(ui)).to_contain_text('-continue-on-error')
    run_import(ui)
    messages = ui.page.locator('.import-messages li')
    expect(messages).to_have_count(3)
    expect(messages.nth(0)).to_have_text('Line 2 NOTICE 02000 no data')
    expect(messages.nth(0)).to_have_class('import-notice')
    expect(messages.nth(1)).to_have_text('Line 3 WARNING 01000 CREATE VIEW failed, so it was ignored: syntax error: view "db".PUBLIC.V needs a column list because column 1 of its query has no name')
    expect(messages.nth(1)).to_have_class('import-warning')
    expect(messages.nth(2)).to_contain_text('Line 4 ERROR 42P01 no such table')
    expect(messages.nth(2)).to_have_class('import-error')
    colors = messages.evaluate_all('items => items.map(item => getComputedStyle(item).color)')
    assert len(set(colors)) == 3


def test_import_messages_while_importing(ui):
    # They're added as they happen.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'big.sql', 'CREATE TABLE foo.other (x INT);\nDELETE FROM foo.other;\n' + big_sql())
    expect(ui.page.locator('.import-options')).to_be_visible()
    run_import(ui)
    message = ui.page.locator('.import-running .import-messages .import-notice')
    expect(message).to_have_text('Line 2 NOTICE 02000 no data', timeout=30000)
    ui.page.locator('.import-cancel').click()


def test_import_in_background(ui, db_file):
    # The progress is shown while the other tabs can be used. Nothing can be seen
    # until it's finished, because it's in one transaction.
    start_big_import(ui)
    expect(ui.page.locator('.import-percent')).to_have_text(re.compile(r'^[\d.]+ (B|KB|MB) / [\d.]+ (B|KB|MB) \(\d+%\)$'), timeout=30000)
    expect(ui.page.locator('.import-operations tr').filter(has_text='CREATE TABLE')).to_be_visible()
    expect(ui.active_tab).to_have_text(re.compile('Import big.sql …'))

    ui.page.locator('.tabs .new').click()
    expect(ui.page.locator('textarea[name="sql"]')).to_be_visible()
    expect(ui.sidebar_table('BIG', schema='FOO')).to_have_count(0)
    ui.page.locator('.tabs .tab').filter(has_text='Import big.sql').locator('button').first.click()
    expect(notice(ui)).to_have_text('big.sql: 4001 statements executed', timeout=120000)
    expect(ui.sidebar_table('BIG', schema='FOO')).to_be_visible()
    assert count(db_file, 'SELECT COUNT(*) FROM foo.big;') == 4000
    expect(ui.page.locator('.import-file')).to_be_visible()


def test_import_cancel(ui, db_file):
    start_big_import(ui)
    ui.page.locator('.import-cancel').click()
    expect(notice(ui)).to_have_text('big.sql: it was cancelled. It was in one transaction, so nothing was changed',
                                    timeout=30000)
    assert 'no such table' in cli(db_file, 'SELECT * FROM foo.big;').lower()
    expect(ui.page.locator('.import-file')).to_be_visible()

    # It can be imported again.
    choose_file(ui, 't.sql', 'CREATE TABLE foo.t (x INT);\n')
    expect(ui.page.locator('.import-options')).to_be_visible()
    run_import(ui)
    expect(notice(ui)).to_have_text('t.sql: 1 statement executed')


def test_import_close_tab_cancels(ui, db_file):
    start_big_import(ui)
    ui.active_tab.locator('.close').click()
    expect(ui.page.locator('.import-cancel')).to_have_count(0)
    # There's nothing left of it, once the process has been stopped.
    ui.page.wait_for_timeout(1000)
    assert 'no such table' in cli(db_file, 'SELECT * FROM foo.big;').lower()


def test_import_interrupted(ui, db_file):
    # The app was stopped while it was importing.
    open_import(ui.catalog_menu('db'))
    cli(db_file, """UPDATE vsql_app.tabs SET payload = '{"schema":"PUBLIC","table":"","on_error":"stop","transaction":true,"running_file":"lost.sql"}' WHERE tab_type = 'IMPORT';""")
    ui.reload()
    expect(ui.error).to_have_text('The import of lost.sql was interrupted because the app was stopped.')
    choose_file(ui, 'a.sql', 'SELECT 1;')
    expect(ui.page.locator('.import-options')).to_be_visible()


def test_import_opens_a_tab(ui):
    # Nothing is shown until there's a file.
    open_import(ui.catalog_menu('db'))
    expect(ui.active_tab).to_have_text(re.compile('Import'))
    expect(ui.page.locator('.import-file')).to_be_visible()
    expect(ui.page.locator('.import-options')).to_be_hidden()


def test_import_menu_fills_in_options(ui, db_file):
    cli(db_file, 'CREATE TABLE foo.p (id INT);')
    ui.reload()
    # A catalog starts with PUBLIC, a schema with itself and a new table, and a
    # table with itself.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'a.sql', 'SELECT 1;')
    expect(ui.page.locator('[name="import_schema"]')).to_have_value('PUBLIC')

    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, 'a.csv', 'id\n1\n')
    expect(ui.page.locator('[name="import_schema"]')).to_have_value('FOO')
    expect(ui.page.locator('[name="import_table"]')).to_have_value('')
    expect(ui.page.locator('[name="import_new"]')).to_have_value('a')

    open_import(ui.table_menu('P', schema='FOO'))
    choose_file(ui, 'a.csv', 'id\n1\n')
    expect(ui.page.locator('[name="import_schema"]')).to_have_value('FOO')
    expect(ui.page.locator('[name="import_table"]')).to_have_value('P')
    expect(ui.page.locator('[name="import_new"]')).to_be_hidden()


def test_import_options_depend_on_file(ui):
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'a.sql', 'SELECT 1;')
    expect(ui.page.locator('[name="import_schema"]')).to_be_visible()
    expect(ui.page.locator('.import-map')).to_be_hidden()
    choose_file(ui, 'a.csv', 'id\n1\n')
    expect(ui.page.locator('[name="import_schema"]')).to_be_visible()
    expect(ui.page.locator('.import-map')).to_be_visible()
    expect(ui.page.locator('.import-hint')).to_be_hidden()


def test_import_sql_stats(ui, db_file):
    # They're an estimate of the text, so it doesn't need to be valid.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'load.sql', """CREATE TABLE foo.a (x INT);
create   table foo.b (x INT); INSERT INTO foo.a (x) VALUES (1);
insert into foo.a (x) VALUES (2);
this is not; SQL at all
""")
    stats = ui.page.locator('.import-stats')
    expect(stats.locator('tr')).to_have_count(2)
    expect(stats.locator('tr').nth(0)).to_have_text('CREATE TABLE~2')
    expect(stats.locator('tr').nth(1)).to_have_text('INSERT~2')
    assert count(db_file, "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'A';") == 0


def test_import_csv_stats(ui):
    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, 'a.csv', 'x,y\n1,2\n3,4\n\n')
    stats = ui.page.locator('.import-stats')
    expect(stats.locator('tr').nth(0)).to_have_text('Rows~2')
    expect(stats.locator('tr').nth(1)).to_have_text('Fields~2')


def test_import_sql(ui, db_file):
    # Every statement runs in the file of the menu. The new table is in the
    # sidebar.
    import_sql(ui, 'load.sql', """-- A comment; with a semicolon.
CREATE TABLE foo.t (x INT);
INSERT INTO foo.t (x) VALUES (1), (2);
""")
    expect(notice(ui)).to_have_text('load.sql: 2 statements executed')
    expect(ui.sidebar_table('T', schema='FOO')).to_be_visible()
    expect(ui.active_tab).to_have_text(re.compile('Import load.sql'))
    assert count(db_file, 'SELECT COUNT(*) FROM foo.t;') == 2


def test_import_sql_schema(ui, db_file):
    # A statement that doesn't name a schema runs in the chosen one.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'load.sql', 'CREATE TABLE t (x INT);\nINSERT INTO t (x) VALUES (1);\n')
    ui.page.locator('[name="import_schema"]').select_option('FOO')
    run_import(ui)
    expect(notice(ui)).to_have_text('load.sql: 2 statements executed')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.t;') == 1


def test_import_sql_stop_changes_nothing(ui, db_file):
    import_sql(ui, 'load.sql', """CREATE TABLE foo.t (x INT);
INSERT INTO foo.t (x) VALUES (1);
INSERT INTO foo.nope (x) VALUES (1);
INSERT INTO foo.t (x) VALUES (2);
""")
    expect(ui.error).to_have_text('load.sql: 2 statements executed, 1 failed. '
                                  'It was rolled back, so nothing was changed')
    expect(failures(ui)).to_have_count(1)
    expect(failures(ui)).to_contain_text('Line 3')
    expect(failures(ui)).to_contain_text('no such table')
    expect(failures(ui)).to_contain_text('INSERT INTO foo.nope')
    assert 'no such table' in cli(db_file, 'SELECT * FROM foo.t;').lower()


def test_import_sql_continue(ui, db_file):
    # Each failure has its own message, and the other statements are kept.
    import_sql(ui, 'load.sql', """CREATE TABLE foo.t (x INT PRIMARY KEY);
INSERT INTO foo.t (x) VALUES (1), (2), (1);
INSERT INTO foo.t (x) VALUES (3);
INSERT INTO foo.nope (x) VALUES (1);
INSERT INTO foo.t (x) VALUES (4);
""", on_error='continue')
    expect(ui.error).to_have_text('load.sql: 3 statements executed, 2 failed')
    expect(failures(ui)).to_have_count(2)
    expect(failures(ui).nth(0)).to_contain_text('Line 2')
    expect(failures(ui).nth(0)).to_contain_text('unique')
    expect(failures(ui).nth(1)).to_contain_text('Line 4')
    expect(failures(ui).nth(1)).to_contain_text('no such table')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.t;') == 2


def test_import_sql_own_transactions(ui, db_file):
    # A file with its own transactions can't be run inside of another one, but can
    # be run with that turned off.
    text = """CREATE TABLE foo.t (x INT);
START TRANSACTION;
INSERT INTO foo.t (x) VALUES (1);
COMMIT;
START TRANSACTION;
INSERT INTO foo.t (x) VALUES (2);
ROLLBACK;
INSERT INTO foo.nope (x) VALUES (1);
"""
    import_sql(ui, 'load.sql', text)
    expect(failures(ui)).to_contain_text('a file with its own transactions')
    expect(failures(ui)).to_contain_text('Line 2')
    expect(ui.error).to_contain_text('rolled back')
    assert 'no such table' in cli(db_file, 'SELECT * FROM foo.t;').lower()

    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'load.sql', text)
    ui.page.locator('[name="import_transaction"]').uncheck()
    run_import(ui)
    expect(ui.error).to_have_text('load.sql: 7 statements executed, 1 failed')
    expect(failures(ui)).to_contain_text('Line 8')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.t;') == 1


def test_import_sql_left_open(ui, db_file):
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'load.sql', """CREATE TABLE foo.t (x INT);
START TRANSACTION;
INSERT INTO foo.t (x) VALUES (1);
""")
    ui.page.locator('[name="import_transaction"]').uncheck()
    run_import(ui)
    expect(ui.error).to_contain_text('The file left a transaction open, so it was rolled back')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.t;') == 0


def test_import_sql_empty(ui):
    import_sql(ui, 'load.sql', '-- Nothing here.\n')
    expect(ui.error).to_contain_text('the file has no statements')


def test_import_report_kept_and_cleared(ui):
    import_sql(ui, 'load.sql', 'CREATE TABLE foo.t (x INT);\n')
    expect(notice(ui)).to_be_visible()
    # A reload doesn't run it again.
    ui.reload()
    expect(notice(ui)).to_have_text('load.sql: 1 statement executed')
    # It's for the file before this one.
    choose_file(ui, 'other.sql', 'SELECT 1;')
    expect(notice(ui)).to_have_count(0)


def test_import_only_posted_by_import(ui, db_file):
    # Going to another tab with a file chosen doesn't import it, the options are
    # kept.
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'load.sql', 'CREATE TABLE foo.t (x INT);\n')
    ui.page.locator('[name="import_schema"]').select_option('FOO')
    ui.page.locator('[name="import_on_error"]').select_option('continue')
    ui.page.locator('.tabs .new').click()
    ui.page.locator('.tabs .tab').filter(has_text='Import').locator('button').first.click()
    choose_file(ui, 'load.sql', 'SELECT 1;')
    expect(ui.page.locator('[name="import_schema"]')).to_have_value('FOO')
    expect(ui.page.locator('[name="import_on_error"]')).to_have_value('continue')
    assert 'no such table' in cli(db_file, 'SELECT * FROM foo.t;').lower()


def test_import_csv_new_table(ui, db_file):
    # The table is named after the file, the types are guessed. An empty value
    # is NULL, and a quoted one is an empty string. A value with a leading zero
    # isn't a number.
    import_table(ui, 'People.csv', 'id,name,score,active,born,zip,big,note\r\n'
                 '1,"a, ""b""",1.50,true,2000-01-02,01234,3000000000,\r\n'
                 '2,,10.25,FALSE,2001-12-31,90210,4,""\r\n')
    expect(notice(ui)).to_have_text('People.csv: 2 rows inserted')
    view_table(ui)
    expect(ui.active_tab).to_have_text(re.compile(r'FOO\.PEOPLE'))
    expect(ui.rows).to_have_count(2)
    columns = cli(db_file, "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'PEOPLE';")
    for name, data_type in {'ID': 'INTEGER', 'NAME': 'CHARACTER VARYING', 'SCORE': 'DECIMAL', 'ACTIVE': 'BOOLEAN',
                            'BORN': 'DATE', 'ZIP': 'CHARACTER VARYING', 'BIG': 'BIGINT', 'NOTE': 'CHARACTER VARYING'}.items():
        assert re.search(rf'{name} +\| {data_type}', columns), columns
    rows = cli(db_file, "SELECT name, score, zip FROM foo.people ORDER BY id;")
    assert 'a, "b"' in rows and '1.5' in rows and '01234' in rows
    assert count(db_file, 'SELECT COUNT(*) FROM foo.people WHERE name IS NULL;') == 1
    assert count(db_file, 'SELECT COUNT(*) FROM foo.people WHERE note IS NULL;') == 1
    assert count(db_file, "SELECT COUNT(*) FROM foo.people WHERE note = '';") == 1


def test_import_new_table_columns(ui, db_file):
    # A field can be renamed, or skipped by clearing its name.
    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, 'p.csv', 'a,b,c\n1,2,3\n')
    ui.page.get_by_label('Column for a').fill('renamed')
    ui.page.get_by_label('Column for b').fill('')
    run_import(ui)
    expect(notice(ui)).to_have_text('p.csv: 1 row inserted')
    columns = cli(db_file, "SELECT column_name FROM information_schema.columns WHERE table_name = 'P';")
    assert 'RENAMED' in columns and 'C' in columns and 'A ' not in columns and 'B' not in columns
    assert count(db_file, 'SELECT renamed FROM foo.p;') == 1


def test_import_new_table_types(ui, db_file):
    # The types are guessed from the first rows, and can be changed. Which is needed
    # here because of a value that's too far into the file to be seen.
    text = 'a,b\n' + ''.join(f'{i},{i}\n' for i in range(150)) + 'text,1\n'
    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, 'p.csv', text)
    expect(ui.page.get_by_label('Type of a')).to_have_value('INTEGER')
    ui.page.get_by_label('Type of b').fill('')
    expect(ui.page.locator('.import-run')).to_be_disabled()
    ui.page.get_by_label('Type of b').fill('BIGINT')
    run_import(ui)
    expect(ui.error).to_contain_text('rolled back, so nothing was changed')
    expect(failures(ui)).to_contain_text('Line 152')
    assert 'no such table' in cli(db_file, 'SELECT * FROM foo.p;').lower()

    open_import(ui.schema_menu('db', 'FOO'))
    choose_file(ui, 'p.csv', text)
    ui.page.get_by_label('Type of a').fill('VARCHAR(10)')
    run_import(ui)
    expect(notice(ui)).to_have_text('p.csv: 151 rows inserted')
    assert re.search(r'A +\| CHARACTER VARYING', cli(db_file, "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'P';"))


def test_import_table_mapping(ui, db_file):
    # A field goes to the column of the same name in any case, the others are
    # skipped until they're mapped. Generated columns can't be chosen.
    cli(db_file, 'CREATE TABLE foo.p (id INT PRIMARY KEY, name VARCHAR(10), g INT GENERATED ALWAYS AS (id + 1));')
    ui.reload()
    open_import(ui.table_menu('P', schema='FOO'))
    choose_file(ui, 'p.csv', 'ID,full_name,other\n7,seven,x\n')
    expect(ui.page.get_by_label('Column for ID')).to_have_value('ID')
    expect(ui.page.get_by_label('Column for full_name')).to_have_value('')
    expect(ui.page.get_by_label('Column for other').locator('option')).to_have_text(['Skip', 'ID', 'NAME'])
    ui.page.get_by_label('Column for full_name').select_option('NAME')
    run_import(ui)
    expect(notice(ui)).to_have_text('p.csv: 1 row inserted')
    assert count(db_file, "SELECT id FROM foo.p WHERE name = 'seven';") == 7


def test_import_change_table_changes_mapping(ui, db_file):
    cli(db_file, 'CREATE TABLE foo.a (x INT); CREATE TABLE foo.b (y INT);')
    ui.reload()
    open_import(ui.table_menu('A', schema='FOO'))
    choose_file(ui, 'f.csv', 'y\n1\n')
    expect(ui.page.get_by_label('Column for y')).to_have_value('')
    expect(ui.page.locator('.import-run')).to_be_disabled()
    ui.page.locator('[name="import_table"]').select_option('B')
    expect(ui.page.get_by_label('Column for y')).to_have_value('Y')
    expect(ui.page.locator('.import-run')).to_be_enabled()
    ui.page.locator('[name="import_table"]').select_option('')
    expect(ui.page.locator('[name="import_new"]')).to_be_visible()
    ui.page.locator('[name="import_new"]').fill('')
    expect(ui.page.locator('.import-run')).to_be_disabled()


def test_import_mapped_twice(ui, db_file):
    cli(db_file, 'CREATE TABLE foo.p (x INT);')
    ui.reload()
    open_import(ui.table_menu('P', schema='FOO'))
    choose_file(ui, 'p.csv', 'x,y\n1,2\n')
    ui.page.get_by_label('Column for y').select_option('X')
    run_import(ui)
    expect(failures(ui)).to_contain_text('more than one column named X')
    expect(ui.error).to_contain_text('rolled back, so nothing was changed')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.p;') == 0


def test_import_multiline_and_bom(ui, db_file):
    import_table(ui, 'notes.csv', '﻿id,body\n1,"two\nlines"\n\n2,x', table='notes')
    expect(notice(ui)).to_have_text('notes.csv: 2 rows inserted')
    assert count(db_file, "SELECT COUNT(*) FROM foo.notes WHERE id = 2 AND body = 'x';") == 1
    assert 'ID' in cli(db_file, 'SELECT id FROM foo.notes;')


def test_import_tsv_new_table(ui, db_file):
    import_table(ui, 'scores.tsv', 'name\tscore\na,b\t1\nc\t2\n')
    expect(notice(ui)).to_have_text('scores.tsv: 2 rows inserted')
    assert count(db_file, "SELECT score FROM foo.scores WHERE name = 'a,b';") == 1


def test_import_json_new_table(ui, db_file):
    # A key that's only in some rows is NULL in a new table. A number stays
    # exact, and a string that looks like a number stays a string.
    import_table(ui, 'items.json', r"""[
  {"id": 1, "price": 1.50, "code": "007", "ok": true, "s": "é\né😀"},
  {"id": 2, "price": 12345678901234.25, "code": "8", "ok": null}
]""")
    expect(notice(ui)).to_have_text('items.json: 2 rows inserted')
    columns = cli(db_file, "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'ITEMS';")
    assert re.search(r'CODE +\| CHARACTER VARYING', columns), columns
    assert re.search(r'OK +\| BOOLEAN', columns), columns
    assert '12345678901234.25' in cli(db_file, 'SELECT price FROM foo.items WHERE id = 2;')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.items WHERE s IS NULL;') == 1
    assert count(db_file, "SELECT COUNT(*) FROM foo.items WHERE code = '007' AND s LIKE '%😀';") == 1


@pytest.mark.parametrize('name,text,message', [
    ('a.csv', '', 'the file is empty'),
    ('a.csv', 'x,x\n1,2\n', 'more than one column named x'),
    ('a.csv', 'x,\n1,2\n', 'column 2 has no name'),
    ('a.csv', 'x,y\n1\n', 'Line 2 ERROR HY000 has 1 values, but there are 2 columns'),
    ('a.csv', 'x\n"1\n', 'Line 2 ERROR HY000 a quote is never closed'),
    ('a.csv', 'x\n"1"2\n', 'Line 2 ERROR HY000 unexpected text after a closing quote'),
    ('a.json', '{"x": 1}', 'the file must be an array of objects'),
    ('a.json', '[1]', 'each row must be an object'),
    ('a.json', '[{"x": [1]}]', 'x is an object or array'),
    ('a.json', '[{"x": 1}', 'expected "," or "]"'),
    ('a.json', '[{"x": 1}] 2', 'unexpected text after the array'),
    ('a.json', '[{"x": tru}]', 'expected a value'),
    ('a.json', '[{"x": "\\q"}]', 'unknown escape'),
    ('a.json', '[{"x": "1}]', 'a string is never closed'),
])
def test_import_bad_file(ui, db_file, name, text, message):
    # A file that can't be read leaves the table as it was.
    cli(db_file, 'CREATE TABLE foo.bad (x INT, y INT);')
    ui.reload()
    import_rows(ui, 'BAD', name, text)
    expect(failures(ui)).to_contain_text(message)
    expect(ui.error).to_contain_text('rolled back, so nothing was changed')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.bad;') == 0


def test_import_empty_json(ui, db_file):
    cli(db_file, 'CREATE TABLE foo.p (x INT);')
    ui.reload()
    import_rows(ui, 'P', 'p.json', '[]')
    expect(notice(ui)).to_have_text('p.json: 0 rows inserted')


def test_import_rows(ui, db_file):
    # A column that's not in the file gets its DEFAULT, as does a key that's not
    # in a JSON row.
    cli(db_file, "CREATE TABLE foo.p (id INT PRIMARY KEY, name VARCHAR(10) DEFAULT 'none', d DATE, g INT GENERATED ALWAYS AS (id + 1));")
    ui.reload()
    import_rows(ui, 'P', 'p.csv', 'ID,d\n1,2024-01-02\n')
    expect(notice(ui)).to_have_text('p.csv: 1 row inserted')
    import_rows(ui, 'P', 'p.json', '[{"id": 2, "NAME": "two"}, {"id": 3}, {"id": 4, "NAME": null}]')
    expect(notice(ui)).to_have_text('p.json: 3 rows inserted')
    assert count(db_file, "SELECT COUNT(*) FROM foo.p WHERE name = 'none';") == 2
    assert count(db_file, 'SELECT COUNT(*) FROM foo.p WHERE name IS NULL;') == 1
    assert count(db_file, "SELECT id FROM foo.p WHERE d = DATE '2024-01-02';") == 1


def test_import_rows_stop_changes_nothing(ui, db_file):
    cli(db_file, 'CREATE TABLE foo.p (id INT PRIMARY KEY, n INT);')
    ui.reload()
    for name, text, number in [
        ('p.csv', 'id\n1\n1\n3\n', 'Line 3'),
        ('p.csv', 'id,n\n1,x\n', 'Line 2'),
    ]:
        import_rows(ui, 'P', name, text)
        expect(ui.error).to_contain_text('rolled back, so nothing was changed')
        expect(failures(ui)).to_contain_text(number)
    assert count(db_file, 'SELECT COUNT(*) FROM foo.p;') == 0


def test_import_rows_continue(ui, db_file):
    cli(db_file, 'CREATE TABLE foo.p (id INT PRIMARY KEY);')
    ui.reload()
    import_rows(ui, 'P', 'p.csv', 'id\n1\n1\n2\n2\n3\n', on_error='continue')
    expect(ui.error).to_have_text('p.csv: 3 rows inserted, 2 failed')
    expect(failures(ui)).to_have_count(2)
    expect(failures(ui).nth(0)).to_contain_text('Line 3')
    expect(failures(ui).nth(1)).to_contain_text('Line 5')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.p;') == 3


def test_import_wrong_file_type(ui):
    open_import(ui.catalog_menu('db'))
    choose_file(ui, 'a.txt', 'x\n1\n')
    expect(ui.page.locator('.import-message')).to_contain_text('cannot be imported')
    expect(ui.page.locator('.import-options')).to_be_hidden()


def test_export_then_import(ui, db_file):
    # What's exported can be imported again. NULL and an empty string are kept.
    cli(db_file, """CREATE TABLE foo.p (id INT PRIMARY KEY, s VARCHAR(10));
INSERT INTO foo.p (id, s) VALUES (1, ''), (2, NULL), (3, 'a,"b"');""")
    ui.reload()
    for extension, option in {'csv': 'CSV', 'tsv': 'TSV', 'json': 'JSON'}.items():
        ui.table_menu('P', schema='FOO').get_by_role('button', name='Export').click()
        ui.export_check(option)
        _, text = ui.download(ui.page.locator('.export').get_by_role('button', name='Export', exact=True))
        import_table(ui, f'copy_{extension}.{extension}', text)
        expect(notice(ui)).to_contain_text('3 rows inserted')
        table = f'foo.copy_{extension}'
        assert count(db_file, f"SELECT id FROM {table} WHERE s = '';") == 1
        assert count(db_file, f'SELECT id FROM {table} WHERE s IS NULL;') == 2
        assert count(db_file, f"""SELECT id FROM {table} WHERE s = 'a,"b"';""") == 3
