# Exporting a result from the Export menu, and a table or schema from its menu
# in the sidebar.

from playwright.sync_api import expect

from conftest import cli, count


def test_export_result(ui, db_file):
    # The rows of the result are downloaded as CSV or JSON. The SQL is run
    # again in a transaction that's rolled back, so the INSERT isn't done
    # again. The menu is closed, and the page stays the same.
    ui.new_tab()
    ui.run('INSERT INTO foo.bar (y) VALUES (TRUE); SELECT * FROM foo.bar')
    expect(ui.rows).to_have_count(1)
    filename, text = ui.download(ui.export_menu().get_by_role('button', name='CSV'))
    assert (filename, text) == ('result.csv', 'Y\r\nTRUE\r\n')
    expect(ui.page.locator('.actions details.export')).not_to_have_attribute('open', '')
    filename, text = ui.download(ui.export_menu().get_by_role('button', name='JSON'))
    assert (filename, text) == ('result.json', '[\n  {"Y": true}\n]\n')
    assert count(db_file, 'SELECT COUNT(*) FROM foo.bar;') == 1
    expect(ui.rows).to_have_count(1)

    # Only rows can be exported.
    ui.run('INSERT INTO foo.bar (y) VALUES (FALSE)')
    expect(ui.page.locator('.actions details.export')).to_have_count(0)


def test_export_values(ui, db_file):
    # A value is quoted in CSV when it has to be, and a NULL is empty. In JSON
    # an integer is a number, and anything else (other than a BOOLEAN) is a
    # string.
    cli(db_file, """CREATE TABLE foo.v (x INT, y VARCHAR(10), z DECIMAL(3, 1));
INSERT INTO foo.v VALUES (1, 'a,b', 1.5);
INSERT INTO foo.v (x, y) VALUES (2, ' "q"');""")
    ui.new_tab()
    ui.run('SELECT * FROM foo.v ORDER BY x')
    _, text = ui.download(ui.export_menu().get_by_role('button', name='CSV'))
    assert text == 'X,Y,Z\r\n1,"a,b",1.5\r\n2," ""q""",\r\n'
    _, text = ui.download(ui.export_menu().get_by_role('button', name='JSON'))
    assert text == '[\n  {"X": 1, "Y": "a,b", "Z": "1.5"},\n  {"X": 2, "Y": " \\"q\\"", "Z": null}\n]\n'


def test_export_table(ui, db_file):
    # A table is exported as CSV, JSON or SQL (CREATE TABLE and its rows).
    cli(db_file, 'INSERT INTO foo.bar (y) VALUES (TRUE);')
    filename, text = ui.download(ui.table_menu('BAR', schema='FOO').get_by_role('button', name='Export as CSV'))
    assert (filename, text) == ('BAR.csv', 'Y\r\nTRUE\r\n')
    filename, text = ui.download(ui.table_menu('BAR', schema='FOO').get_by_role('button', name='Export as JSON'))
    assert (filename, text) == ('BAR.json', '[\n  {"Y": true}\n]\n')
    filename, text = ui.download(ui.table_menu('BAR', schema='FOO').get_by_role('button', name='Export as SQL'))
    assert filename == 'BAR.sql'
    assert text.startswith('CREATE TABLE "FOO"."BAR"')
    assert 'CREATE SCHEMA' not in text
    assert 'INSERT INTO "FOO"."BAR" ("Y") VALUES (TRUE);' in text


def test_export_schema(ui, db_file, make_file):
    # A schema is exported as SQL with its tables and rows, which can be
    # loaded into another file.
    cli(db_file, 'INSERT INTO foo.bar (y) VALUES (TRUE);')
    filename, text = ui.download(ui.schema_menu('db', 'FOO').get_by_role('button', name='Export as SQL'))
    assert filename == 'FOO.sql'
    other_file = make_file('other.vsql', text)
    assert count(other_file, 'SELECT COUNT(*) FROM foo.bar WHERE y;') == 1
