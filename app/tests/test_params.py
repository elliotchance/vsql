# The values of each "?" in the SQL of a tab: they have an input under the editor
# and are kept in the payload of the tab.

import re

from playwright.sync_api import expect

from conftest import cli


def test_inputs(ui):
    # There's an input for each "?" as it's typed, but not for one in a string,
    # quoted name or comment. A value is kept while its "?" is there.
    ui.new_tab()
    ui.editor.fill('SELECT 1')
    expect(ui.params).to_have_count(0)
    expect(ui.page.locator('.params')).to_be_hidden()
    ui.editor.fill('VALUES ?, ?')
    expect(ui.params).to_have_count(2)
    ui.param(1).fill('a')
    ui.editor.fill('VALUES ?')
    expect(ui.params).to_have_count(1)
    expect(ui.param(1)).to_have_value('a')
    ui.editor.fill("""VALUES '?', "?" -- ?
    /* ? */""")
    expect(ui.params).to_have_count(0)


def test_saved_in_payload(ui, db_file):
    # The values are saved in the tab with the SQL, and restored.
    ui.new_tab()
    ui.editor.fill('VALUES ?, ?')
    ui.param(1).fill('a')
    ui.param(2).fill("it's")
    ui.new_tab()
    ui.tab_bar.nth(0).locator('button').first.click()
    expect(ui.param(1)).to_have_value('a')
    expect(ui.param(2)).to_have_value("it's")
    assert '"params":["a","it\'s"]' in cli(db_file, 'SELECT payload FROM vsql_app.tabs ORDER BY id FETCH FIRST 1 ROW ONLY;')


def run(ui):
    ui.page.get_by_role('button', name=re.compile('^Run')).click()


def test_guess(ui):
    # The type is guessed from the value, as it's typed.
    ui.new_tab()
    ui.editor.fill('VALUES ?')
    expect(ui.param_type(1).locator('option:checked')).to_have_text('Auto (Text)')
    for value, name, type_name, shown in [
            ('1', 'Number', 'NUMERIC', '1'), ('1.5', 'Number', 'NUMERIC', '1.5'),
            ('1e2', 'Number', 'DOUBLE PRECISION', '100e0'), ('abc', 'Text', 'CHARACTER VARYING', 'abc'),
            ('true', 'Boolean', 'BOOLEAN', 'TRUE'), ('2020-01-02', 'Date', 'DATE', '2020-01-02'),
            ('2020-01-02 03:04:05', 'Timestamp', 'TIMESTAMP', '2020-01-02T03:04:05'),
            ('03:04:05', 'Time', 'TIME', '03:04:05')]:
        ui.editor.fill('VALUES ?')
        ui.param(1).fill(value)
        expect(ui.param_type(1).locator('option:checked')).to_have_text(f'Auto ({name})')
        run(ui)
        expect(ui.status).to_have_text(re.compile(r'^1 row \('))
        expect(ui.headers).to_have_text(re.compile(type_name))
        expect(ui.cells.first).to_contain_text(shown)


def test_choose_type(ui, db_file):
    # A type that's chosen stays when the value changes, and is restored. It can
    # be chosen before there's a value.
    ui.new_tab()
    ui.editor.fill('VALUES ?')
    ui.param_type(1).select_option('Text')
    ui.param(1).fill('false')
    expect(ui.param_type(1)).to_have_value('text')
    run(ui)
    expect(ui.headers).to_have_text(re.compile('CHARACTER VARYING'))
    expect(ui.cells.first).to_have_text('false')
    expect(ui.param_type(1)).to_have_value('text')
    assert '"param_types":["text"]' in cli(db_file, 'SELECT payload FROM vsql_app.tabs;')

    # Auto goes back to guessing.
    ui.param_type(1).select_option(index=0)
    expect(ui.param_type(1).locator('option:checked')).to_have_text('Auto (Boolean)')
    run(ui)
    expect(ui.headers).to_have_text(re.compile('BOOLEAN'))
    assert '"param_types":["auto:boolean"]' in cli(db_file, 'SELECT payload FROM vsql_app.tabs;')

    # Text can be empty.
    ui.param_type(1).select_option('Text')
    ui.param(1).fill('')
    run(ui)
    expect(ui.status).to_have_text(re.compile(r'^1 row \('))
    expect(ui.cells.first).to_have_text('')

    # TRUE, FALSE, UNKNOWN and NULL are the value, so there's no input.
    ui.param(1).fill('abc')
    for name, type_name, shown in [('TRUE', 'BOOLEAN', 'TRUE'), ('FALSE', 'BOOLEAN', 'FALSE'),
                                   ('UNKNOWN', 'BOOLEAN', 'UNKNOWN'), ('NULL', 'CHARACTER VARYING', 'NULL')]:
        ui.param_type(1).select_option(name)
        expect(ui.param(1)).to_be_hidden()
        run(ui)
        expect(ui.headers).to_have_text(re.compile(type_name))
        expect(ui.cells.first).to_have_text(shown)
        expect(ui.param_type(1).locator('option:checked')).to_have_text(name)
        expect(ui.param(1)).to_be_hidden()

    # The input comes back with its value.
    ui.param_type(1).select_option('Text')
    expect(ui.param(1)).to_be_visible()
    expect(ui.param(1)).to_have_value('abc')


def test_hidden_keeps_numbers(ui):
    # A "?" without an input doesn't change the number of the others.
    ui.new_tab()
    ui.editor.fill('VALUES ROW(?, ?)')
    ui.param_type(1).select_option('NULL')
    ui.param(2).fill('5')
    ui.param(2).press('Enter')
    expect(ui.cells).to_have_text(['NULL', '5'])


def test_type_before_input(ui):
    ui.new_tab()
    ui.editor.fill('VALUES ?')
    label = ui.page.locator('.params label')
    assert label.locator('> *').evaluate_all('e => e.map(x => x.tagName)') == ['SELECT', 'INPUT']


def test_wrong_type(ui):
    # A value that isn't its type is an error.
    ui.new_tab()
    ui.editor.fill('VALUES ?')
    ui.param_type(1).select_option('Number')
    ui.param(1).fill('abc')
    run(ui)
    expect(ui.error).to_have_text('?1: abc is not a number')


def test_typed_columns(ui, db_file):
    # A number compares with a number column, and Text with a string.
    cli(db_file, "CREATE TABLE p (id INT PRIMARY KEY, n VARCHAR(10)); INSERT INTO p (id, n) VALUES (1, '1'), (2, 'b');")
    ui.new_tab()
    ui.editor.fill('SELECT id FROM p WHERE id = ? AND n = ?')
    ui.param(1).fill('1')
    ui.param(2).fill('1')
    ui.param_type(2).select_option('Text')
    ui.param(2).press('Enter')
    expect(ui.status).to_have_text(re.compile(r'^1 row \('))
    expect(ui.cells.first).to_have_text('1')
    expect(ui.param(2)).to_have_value('1')


def test_missing_value(ui):
    ui.new_tab()
    ui.editor.fill('VALUES ?, ?')
    ui.param(1).fill('1')
    run(ui)
    expect(ui.error).to_have_text('?2: no value')
    expect(ui.param(1)).to_have_value('1')


def test_multiple_statements(ui):
    # The "?"s are numbered through all of the statements.
    ui.new_tab()
    ui.editor.fill('VALUES ?; VALUES ?')
    ui.param(1).fill('1')
    ui.param(2).fill('2')
    ui.param(2).press('Enter')
    expect(ui.cells.first).to_have_text('2')


def test_edit_keeps_params(ui, db_file):
    # Saving changes to rows runs the query again with the same values.
    cli(db_file, "CREATE TABLE p (id INT PRIMARY KEY, n VARCHAR(10)); INSERT INTO p (id, n) VALUES (1, 'a'), (2, 'b');")
    ui.new_tab()
    ui.editor.fill('SELECT * FROM p WHERE id = ?')
    ui.param(1).fill('1')
    ui.param(1).press('Enter')
    expect(ui.status).to_have_text(re.compile(r'^1 row \('))
    ui.edit_button.click()
    ui.edit(0, 'N', 'c')
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change, 1 row \('))
    expect(ui.cell(0, 'N')).to_have_text('c')
