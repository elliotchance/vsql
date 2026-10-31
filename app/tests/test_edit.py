# Changing the rows of SELECT * FROM a table: choosing Edit... collects updates,
# deletes and inserts, then saving runs them in one transaction.

import re

import pytest
from playwright.sync_api import expect

from conftest import cli, count
from pages import AppPage

# edit_sql is the tables in edit.vsql. PK can have its rows changed, NOPK can't.
edit_sql = '''
CREATE TABLE pk (id INT PRIMARY KEY, name VARCHAR(20), ts TIMESTAMP(0), g INT GENERATED ALWAYS AS (id * 2), b BOOLEAN);
INSERT INTO pk (id, name) VALUES (1, 'a');
CREATE TABLE auto (id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name VARCHAR(20) DEFAULT 'x', g INT GENERATED ALWAYS AS (id * 2));
CREATE TABLE nopk (x INT);
INSERT INTO nopk (x) VALUES (1);
'''

select_pk = 'SELECT * FROM pk WHERE id < 10 ORDER BY id'


@pytest.fixture
def edit_file(make_file):
    """edit_file is edit.vsql (the catalog "edit") with edit_sql."""
    return make_file('edit.vsql', edit_sql)


@pytest.fixture
def edit_ui(page, edit_file, start_app):
    """edit_ui is the page of an app started with edit_file, on a tab with
    select_pk."""
    ui = AppPage(page, start_app(edit_file))
    ui.new_tab()
    ui.run(select_pk)
    return ui


def test_read_only_until_edit(edit_ui):
    # Nothing can be changed until Edit... is chosen.
    ui = edit_ui
    expect(ui.edit_button).to_have_text('Edit...')
    expect(ui.cancel_edit).to_be_hidden()
    expect(ui.page.locator('main .row-actions').first).to_be_hidden()
    expect(ui.page.locator('main tfoot')).to_be_hidden()
    ui.cell(0, 'NAME').click()
    expect(ui.control(0, 'NAME')).to_have_count(0)

    # Then each cell can be edited, except a generated column.
    ui.edit_button.click()
    expect(ui.edit_button).to_have_text('Cancel edit')
    expect(ui.rows.nth(0).locator('td[data-column]')).to_have_text(['1', 'a', '\\N', 'UNKNOWN'])
    expect(ui.rows.nth(0).locator('td:not([data-column])')).to_have_text(['×', '2'])

    # Cancel edit without changes goes back.
    ui.edit_button.click()
    expect(ui.edit_button).to_have_text('Edit...')
    expect(ui.page.locator('main tfoot')).to_be_hidden()

    # Only the rows of SELECT * FROM a table (with a WHERE, ORDER BY, etc) with
    # a PRIMARY KEY can be changed.
    for sql in ['SELECT id, name, ts, g, b FROM pk', 'SELECT DISTINCT * FROM pk',
                'SELECT * FROM pk AS p', 'SELECT * FROM (SELECT * FROM pk) AS p',
                'SELECT * FROM pk; SELECT * FROM pk', 'SELECT * FROM nopk']:
        ui.run(sql)
        expect(ui.status).to_have_text(re.compile(r' rows? \('))
        expect(ui.editable).to_have_count(0)
        expect(ui.edit_button).to_be_disabled()
        expect(ui.edit_button).to_have_attribute('title', re.compile('PRIMARY KEY'))

    # A statement without rows has nothing to edit.
    ui.run('UPDATE nopk SET x = 1')
    expect(ui.edit_button).to_have_count(0)


def test_table_does_not_move(edit_ui):
    # Once editing, opening a cell doesn't move the columns.
    ui = edit_ui
    ui.edit_button.click()
    before = ui.cell(0, 'B').bounding_box()
    ui.cell(0, 'NAME').click()
    expect(ui.control(0, 'NAME')).to_be_focused()
    assert ui.cell(0, 'B').bounding_box() == before


def test_update(edit_ui, edit_file):
    # An update is highlighted and collected, it's not run until it's saved.
    # Then the SQL of the tab is run again.
    ui = edit_ui
    ui.edit_button.click()
    ui.edit(0, 'NAME', "it's")
    expect(ui.rows.nth(0)).to_have_class('updated')
    expect(ui.edit_button).to_have_text('Save 1 change')
    expect(ui.cancel_edit).to_be_visible()
    assert re.search(r'^a *$', cli(edit_file, 'SELECT name FROM pk;'), re.MULTILINE)

    # Other columns of the same row are the same change.
    ui.cell(0, 'B').click()
    ui.control(0, 'B').select_option('TRUE')
    ui.control(0, 'B').press('Enter')
    expect(ui.edit_button).to_have_text('Save 1 change')

    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change, 1 row \('))
    expect(ui.rows.nth(0).locator('td[data-column]')).to_have_text(['1', "it's", 'NULL', 'TRUE'])
    expect(ui.edit_button).to_have_text('Edit...')
    expect(ui.editor).to_have_value(select_pk)


def test_update_back_is_no_change(edit_ui):
    # Changing a value back isn't a change. Escape puts back the cell.
    ui = edit_ui
    ui.edit_button.click()
    ui.edit(0, 'NAME', 'b')
    ui.edit(0, 'NAME', 'a')
    expect(ui.rows.nth(0)).not_to_have_class('updated')
    expect(ui.edit_button).to_have_text('Cancel edit')

    ui.cell(0, 'NAME').click()
    ui.control(0, 'NAME').fill('b')
    expect(ui.edit_button).to_have_text('Save 1 change')
    ui.control(0, 'NAME').press('Escape')
    expect(ui.cell(0, 'NAME')).to_have_text('a')
    expect(ui.edit_button).to_have_text('Cancel edit')


def test_row_button(edit_ui):
    # A row can be deleted with a red ×. A row that's updated or deleted has a
    # yellow button to undo it, and a row that's added has a yellow × to remove
    # it.
    ui = edit_ui
    ui.edit_button.click()
    button = ui.row_button(0)
    expect(button).to_have_text('×')
    expect(button).to_have_class('delete')

    # While typing, undo puts back the row.
    ui.edit(0, 'NAME', 'b')
    ui.edit(0, 'ID', '5')
    expect(button).to_have_text('↺')
    expect(button).to_have_class('undo')
    expect(button).to_have_attribute('title', 'Undo')
    ui.cell(0, 'NAME').click()
    ui.control(0, 'NAME').fill('c')
    button.click()
    expect(ui.rows.nth(0).locator('td[data-column]')).to_have_text(['1', 'a', '\\N', 'UNKNOWN'])
    expect(ui.rows.nth(0)).not_to_have_class('updated')
    expect(button).to_have_class('delete')
    expect(ui.edit_button).to_have_text('Cancel edit')

    # A value that was NULL goes back to NULL.
    ui.edit(0, 'TS', '2020-01-02 03:04:05')
    button.click()
    expect(ui.cell(0, 'TS')).to_have_text('\\N')
    expect(ui.cell(0, 'TS')).to_have_class('null')

    button.click()
    expect(ui.rows.nth(0)).to_have_class('deleted')
    expect(button).to_have_text('↺')
    expect(button).to_have_class('undo')
    button.click()
    expect(button).to_have_class('delete')

    ui.add_row()
    expect(ui.row_button(1)).to_have_text('×')
    expect(ui.row_button(1)).to_have_class('undo')
    expect(ui.row_button(1)).to_have_attribute('title', 'Remove')


def test_special_values(edit_ui, edit_file):
    # The special values are shown while editing: \\N is NULL and "" is an empty
    # string.
    ui = edit_ui
    expect(ui.edit_hint).to_be_hidden()
    expect(ui.cell(0, 'TS')).to_have_text('NULL')
    ui.edit_button.click()
    expect(ui.edit_hint).to_have_text('Empty = DEFAULT, \\N = NULL, "" = empty string')
    expect(ui.cell(0, 'TS')).to_have_text('\\N')

    ui.edit(0, 'NAME', '""')
    expect(ui.cell(0, 'NAME')).to_have_class('null')
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change'))
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = '';") == 1
    expect(ui.cell(0, 'NAME')).to_have_text('')

    ui.edit_button.click()
    expect(ui.cell(0, 'NAME')).to_have_text('""')
    ui.edit(0, 'NAME', '\\N')
    ui.edit_button.click()
    expect(ui.edit_button).to_have_text('Edit...')
    assert count(edit_file, 'SELECT COUNT(*) FROM pk WHERE name IS NULL;') == 1

    # Cancel edit shows the result as it was.
    ui.edit_button.click()
    ui.edit_button.click()
    expect(ui.cell(0, 'NAME')).to_have_text('NULL')
    expect(ui.edit_hint).to_be_hidden()


def test_empty_is_default(edit_ui, edit_file):
    # An empty value is always the DEFAULT, including for an update.
    ui = edit_ui
    cli(edit_file, "INSERT INTO auto (name) VALUES ('y');")
    ui.run('SELECT * FROM auto')
    ui.edit_button.click()
    ui.edit(0, 'NAME', '')
    expect(ui.cell(0, 'NAME')).to_have_text('DEFAULT')
    expect(ui.rows.nth(0)).to_have_class('updated')
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change'))
    assert count(edit_file, "SELECT COUNT(*) FROM auto WHERE name = 'x';") == 1


def test_required(edit_ui, edit_file):
    # A NOT NULL column without a DEFAULT shows when it has no value.
    ui = edit_ui
    ui.edit_button.click()
    ui.add_row()
    expect(ui.cell(1, 'ID')).to_contain_class('missing')
    expect(ui.control(1, 'ID')).to_have_attribute('placeholder', 'required')
    ui.control(1, 'ID').fill('2')
    expect(ui.cell(1, 'ID')).not_to_contain_class('missing')
    ui.control(1, 'ID').fill('')
    ui.control(1, 'ID').press('Enter')
    expect(ui.cell(1, 'ID')).to_have_text('required')
    expect(ui.cell(1, 'ID')).to_contain_class('missing')
    expect(ui.cell(1, 'NAME')).to_have_text('DEFAULT')
    expect(ui.cell(1, 'NAME')).not_to_contain_class('missing')

    # Also when it's cleared in a row that's updated.
    ui.edit(0, 'ID', '')
    expect(ui.cell(0, 'ID')).to_have_text('required')

    # A column with a DEFAULT or an identity column doesn't need a value.
    ui.run('SELECT * FROM auto')
    ui.page.on('dialog', lambda dialog: dialog.accept())
    ui.edit_button.click()
    ui.add_row()
    ui.control(0, 'NAME').press('Enter')
    expect(ui.cell(0, 'NAME')).to_have_text('DEFAULT')
    expect(ui.page.locator('main td.missing')).to_have_count(0)


def test_delete(edit_ui, edit_file):
    # A delete is highlighted, and can be undone.
    ui = edit_ui
    ui.edit_button.click()
    ui.delete_row(0)
    expect(ui.rows.nth(0)).to_have_class('deleted')
    expect(ui.edit_button).to_have_text('Save 1 change')

    # A deleted row can't be edited.
    ui.cell(0, 'NAME').click()
    expect(ui.control(0, 'NAME')).to_have_count(0)

    ui.delete_row(0)
    expect(ui.rows.nth(0)).not_to_have_class('deleted')
    expect(ui.edit_button).to_have_text('Cancel edit')

    ui.delete_row(0)
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change, 0 rows \('))
    assert count(edit_file, 'SELECT COUNT(*) FROM pk;') == 0


def test_insert(edit_ui, edit_file):
    # An insert adds a highlighted row. A column that's left empty isn't
    # inserted, so it gets its DEFAULT.
    ui = edit_ui
    ui.edit_button.click()
    ui.add_row()
    expect(ui.rows.nth(1)).to_have_class('inserted')
    expect(ui.control(1, 'ID')).to_be_focused()
    expect(ui.rows.nth(1).locator('td').nth(4)).to_have_text('generated')

    # It's a change, even before it has any values.
    expect(ui.edit_button).to_have_text('Save 1 change')
    ui.control(1, 'ID').fill('2')
    expect(ui.edit_button).to_have_text('Save 1 change')
    ui.control(1, 'ID').press('Tab')
    ui.control(1, 'NAME').fill('b')
    ui.control(1, 'NAME').press('Enter')
    expect(ui.cell(1, 'TS')).to_have_text('DEFAULT')
    ui.cell(1, 'B').click()
    ui.control(1, 'B').select_option('TRUE')
    ui.control(1, 'B').press('Enter')

    # × removes a row that's not inserted yet.
    ui.add_row()
    ui.control(2, 'ID').fill('3')
    expect(ui.edit_button).to_have_text('Save 2 changes')
    ui.delete_row(2)
    expect(ui.rows).to_have_count(2)
    expect(ui.edit_button).to_have_text('Save 1 change')

    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change, 2 rows \('))
    assert re.search(r'^b +\| +4 \| TRUE$', cli(edit_file, 'SELECT name, g, b FROM pk WHERE id = 2;'), re.MULTILINE)


def test_insert_without_values(edit_ui, edit_file):
    # A row doesn't need any values, they might all be DEFAULT or generated.
    ui = edit_ui
    ui.run('SELECT * FROM auto')
    ui.edit_button.click()
    ui.add_row()
    ui.control(0, 'NAME').press('Enter')
    expect(ui.rows.nth(0)).to_have_class('inserted')
    expect(ui.edit_button).to_have_text('Save 1 change')
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change, 1 row \('))
    assert count(edit_file, "SELECT COUNT(*) FROM auto WHERE name = 'x' AND g = id * 2;") == 1

    # If a column needs a value, the error says so and the row is kept.
    ui.run(select_pk)
    ui.edit_button.click()
    ui.add_row()
    ui.control(1, 'ID').press('Enter')
    ui.edit_button.click()
    expect(ui.error).to_contain_text('violates non-null constraint')
    expect(ui.rows.nth(1)).to_have_class('inserted')
    assert count(edit_file, 'SELECT COUNT(*) FROM pk;') == 1


def test_cancel(edit_ui, edit_file):
    # Cancel edit throws away all of the changes.
    ui = edit_ui
    ui.edit_button.click()
    ui.edit(0, 'NAME', 'b')
    ui.add_row()
    ui.control(1, 'ID').fill('2')
    ui.control(1, 'ID').press('Enter')
    expect(ui.edit_button).to_have_text('Save 2 changes')
    ui.cancel_edit.click()
    expect(ui.edit_button).to_have_text('Edit...')
    expect(ui.cancel_edit).to_be_hidden()
    expect(ui.rows).to_have_count(1)
    expect(ui.rows.nth(0)).not_to_have_class('updated')
    expect(ui.cell(0, 'NAME')).to_have_text('a')
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = 'a';") == 1

    # The rows can be edited again.
    ui.edit_button.click()
    ui.edit(0, 'NAME', 'c')
    expect(ui.edit_button).to_have_text('Save 1 change')


def test_transaction(edit_ui, edit_file):
    # All of the changes are run in one transaction. If one fails nothing is
    # saved, and the changes are kept to try again.
    ui = edit_ui
    ui.edit_button.click()
    ui.edit(0, 'NAME', 'b')
    ui.add_row()
    ui.control(1, 'ID').fill('1')
    ui.control(1, 'ID').press('Enter')
    expect(ui.edit_button).to_have_text('Save 2 changes')
    ui.edit_button.click()
    expect(ui.error).to_contain_text('PRIMARY KEY')
    expect(ui.error).to_contain_text('nothing was saved')
    expect(ui.edit_button).to_have_text('Save 2 changes')
    expect(ui.rows.nth(0)).to_have_class('updated')
    expect(ui.rows.nth(1)).to_have_class('inserted')
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = 'a';") == 1
    assert count(edit_file, 'SELECT COUNT(*) FROM pk;') == 1

    ui.edit(1, 'ID', '2')
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 2 changes, 2 rows \('))
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = 'b';") == 1
    assert count(edit_file, 'SELECT COUNT(*) FROM pk;') == 2


def test_delete_then_insert(edit_ui, edit_file):
    # The deletes run first, so a row can be replaced with the same key.
    ui = edit_ui
    ui.edit_button.click()
    ui.add_row()
    ui.control(1, 'ID').fill('1')
    ui.control(1, 'ID').press('Tab')
    ui.control(1, 'NAME').fill('new')
    ui.control(1, 'NAME').press('Enter')
    ui.delete_row(0)
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 2 changes, 1 row \('))
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE id = 1 AND name = 'new';") == 1


def test_one_row(edit_ui, edit_file):
    # A change must be to exactly one row, otherwise it's rolled back, such as
    # when the row was deleted since it was shown.
    ui = edit_ui
    ui.edit_button.click()
    ui.delete_row(0)
    cli(edit_file, 'DELETE FROM pk;')
    ui.edit_button.click()
    expect(ui.error).to_have_text('DELETE FROM PUBLIC.PK WHERE ID = 1: changed DELETE 0, it must change 1 row: nothing was saved')
    expect(ui.status).to_have_text(re.compile(r'^1 row \('))


def test_catalogs(page, db_file, edit_file, start_app):
    # A table in another catalog is changed with its catalog.
    ui = AppPage(page, start_app(db_file, edit_file))
    ui.new_tab()
    ui.run('SELECT * FROM "edit".PUBLIC.PK')
    expect(ui.editable).to_have_attribute('data-catalog', 'edit')
    ui.edit_button.click()
    ui.edit(0, 'NAME', 'b')
    ui.edit_button.click()
    expect(ui.status).to_have_text(re.compile(r'^Saved 1 change, 1 row \('))
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = 'b';") == 1
