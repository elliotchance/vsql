# Changing the rows of SELECT * FROM a table: updating, deleting and inserting
# rows, which are confirmed (except an insert) before they're run.

import re

import pytest
from playwright.sync_api import expect

from conftest import cli, count
from pages import AppPage

# edit_sql is the tables in edit.vsql. PK can have its rows changed, NOPK can
# only have rows inserted.
edit_sql = '''
CREATE TABLE pk (id INT PRIMARY KEY, name VARCHAR(20), ts TIMESTAMP(0), g INT GENERATED ALWAYS AS (id * 2), b BOOLEAN);
INSERT INTO pk (id, name) VALUES (1, 'a');
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


def test_editable(edit_ui):
    # Each cell can be edited, except a generated column. The empty row at the
    # bottom inserts a row.
    ui = edit_ui
    expect(ui.editable).to_have_count(1)
    expect(ui.rows.nth(0).locator('td[data-column]')).to_have_text(['1', 'a', 'NULL', 'UNKNOWN'])
    expect(ui.rows.nth(0).locator('td:not([data-column])')).to_have_text(['×', '2'])
    expect(ui.insert_value('G')).to_have_count(0)
    expect(ui.page.locator('main tfoot td.null')).to_have_text('generated')

    # Only the rows of SELECT * FROM a table (with a WHERE, ORDER BY, etc) can
    # be changed.
    for sql in ['SELECT id, name, ts, g, b FROM pk', 'SELECT DISTINCT * FROM pk',
                'SELECT * FROM pk AS p', 'SELECT * FROM (SELECT * FROM pk) AS p',
                'SELECT * FROM pk; SELECT * FROM pk']:
        ui.run(sql)
        expect(ui.status).to_have_text(re.compile(r' rows? \('))
        expect(ui.editable).to_have_count(0)

    # Without a PRIMARY KEY, rows can only be inserted.
    ui.run('SELECT * FROM nopk')
    expect(ui.editable).to_have_count(1)
    expect(ui.rows.locator('td[data-column]')).to_have_count(0)
    expect(ui.rows.get_by_role('button', name='×')).to_have_count(0)
    expect(ui.insert_value('X')).to_have_count(1)


def test_update(edit_ui, edit_file):
    # An update is shown to be confirmed, it's not run until it is. Then the
    # SQL of the tab is run again.
    ui = edit_ui
    ui.edit(0, 'NAME', "it's")
    expect(ui.confirm_sql).to_have_text("UPDATE PUBLIC.PK SET NAME = 'it''s' WHERE ID = 1")
    expect(ui.confirm_sql.locator('.str')).to_have_text(["'it''s'"])
    assert re.search(r'^a *$', cli(edit_file, 'SELECT name FROM pk;'), re.MULTILINE)
    ui.run_change()
    expect(ui.confirm).to_have_count(0)
    expect(ui.status).to_have_text(re.compile(r'^UPDATE 1, 1 row \('))
    expect(ui.cell(0, 'NAME')).to_have_text("it's")
    expect(ui.editor).to_have_value(select_pk)


def test_edit_row(edit_ui, edit_file):
    # Double-clicking a row makes every column that can be changed an input,
    # and the buttons at the start of the row confirm or cancel. Only the
    # columns that are changed are updated.
    ui = edit_ui
    ui.cell(0, 'NAME').dblclick()
    expect(ui.rows.nth(0).locator('td[data-column] input, td[data-column] select')).to_have_count(4)
    expect(ui.cell(0, 'NAME').locator('input')).to_be_focused()
    expect(ui.rows.nth(0).locator('button.delete')).to_have_count(0)
    ui.cell(0, 'NAME').locator('input').fill('b')
    ui.cell(0, 'B').locator('select').select_option('TRUE')
    ui.confirm_row(0).click()
    expect(ui.confirm_sql).to_have_text('UPDATE PUBLIC.PK SET NAME = \'b\', B = TRUE WHERE ID = 1')
    ui.run_change()
    expect(ui.status).to_have_text(re.compile(r'^UPDATE 1, 1 row \('))
    expect(ui.rows.nth(0).locator('td[data-column]')).to_have_text(['1', 'b', 'NULL', 'TRUE'])


def test_cancel(edit_ui, edit_file):
    # Escape (or the cancel button) puts the row back, and Cancel closes the
    # popup without running the change. Confirming without a change is the
    # same as cancel.
    ui = edit_ui
    ui.cell(0, 'NAME').dblclick()
    ui.cell(0, 'NAME').locator('input').fill('b')
    ui.cell(0, 'NAME').locator('input').press('Escape')
    expect(ui.cell(0, 'NAME')).to_have_text('a')
    expect(ui.rows.nth(0).locator('input')).to_have_count(0)
    expect(ui.rows.nth(0).get_by_role('button', name='×')).to_have_attribute('title', 'Delete')

    ui.cell(0, 'NAME').dblclick()
    ui.cancel_row(0).click()
    expect(ui.cell(0, 'NAME')).to_have_text('a')

    ui.cell(0, 'NAME').dblclick()
    ui.confirm_row(0).click()
    expect(ui.cell(0, 'NAME')).to_have_text('a')
    expect(ui.confirm).to_have_count(0)

    ui.edit(0, 'NAME', 'b')
    ui.confirm.get_by_role('link', name='Cancel').click()
    expect(ui.confirm).to_have_count(0)
    expect(ui.cell(0, 'NAME')).to_have_text('a')
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = 'a';") == 1


def test_insert(edit_ui, edit_file):
    # An insert isn't confirmed, it's run straight away. A column that's left
    # empty isn't inserted, so it gets its DEFAULT.
    ui = edit_ui
    ui.insert_value('ID').fill('2')
    ui.insert_value('NAME').fill('b')
    ui.insert_value('B').select_option('TRUE')
    ui.insert()
    expect(ui.status).to_have_text(re.compile(r'^INSERT 1, 2 rows \('))
    assert re.search(r'^b +\| +4 \| TRUE$', cli(edit_file, 'SELECT name, g, b FROM pk WHERE id = 2;'), re.MULTILINE)

    # Enter inserts too. Nothing entered is an error.
    ui.insert_value('ID').press('Enter')
    expect(ui.error).to_have_text('enter a value for at least one column')

    # If it fails, the values that were entered are kept.
    ui.insert_value('ID').fill('1')
    ui.insert_value('NAME').fill('<keep>')
    ui.insert_value('B').select_option('FALSE')
    ui.insert_value('NAME').press('Enter')
    expect(ui.error).to_contain_text('PRIMARY KEY')
    expect(ui.insert_value('ID')).to_have_value('1')
    expect(ui.insert_value('NAME')).to_have_value('<keep>')
    expect(ui.insert_value('B')).to_have_value('FALSE')
    expect(ui.status).to_have_text(re.compile(r'^INSERT 1, 2 rows \('))
    assert count(edit_file, 'SELECT COUNT(*) FROM pk;') == 2


def test_delete(edit_ui, edit_file):
    # A delete is confirmed with a red button.
    ui = edit_ui
    ui.delete_row(0)
    expect(ui.confirm_sql).to_have_text('DELETE FROM PUBLIC.PK WHERE ID = 1')
    expect(ui.confirm.get_by_role('button', name='Run')).to_have_class('delete')
    ui.run_change()
    expect(ui.status).to_have_text(re.compile(r'^DELETE 1, 0 rows \('))
    assert count(edit_file, 'SELECT COUNT(*) FROM pk;') == 0


def test_one_row(edit_ui, edit_file):
    # A change must be to exactly one row, otherwise it's rolled back, such as
    # when the row was deleted since it was shown. The error is shown with the
    # last result.
    ui = edit_ui
    ui.delete_row(0)
    cli(edit_file, 'DELETE FROM pk;')
    ui.run_change()
    expect(ui.error).to_have_text('DELETE 0: the change must be to 1 row, so it was rolled back')
    expect(ui.status).to_have_text(re.compile(r'^1 row \('))

    cli(edit_file, "INSERT INTO pk (id, name) VALUES (1, 'a'), (2, 'b');")
    ui.page.request.post(ui.app.url, form={'tab': ui.tab_id, 'confirm': "UPDATE PUBLIC.PK SET NAME = 'x'"})
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = 'x';") == 0


def test_catalogs(page, db_file, edit_file, start_app):
    # A table in another catalog is changed with its catalog.
    ui = AppPage(page, start_app(db_file, edit_file))
    ui.new_tab()
    ui.run('SELECT * FROM "edit".PUBLIC.PK')
    expect(ui.editable).to_have_attribute('data-catalog', 'edit')
    ui.edit(0, 'NAME', 'b')
    expect(ui.confirm_sql).to_have_text("UPDATE \"edit\".PUBLIC.PK SET NAME = 'b' WHERE ID = 1")
    ui.run_change()
    expect(ui.status).to_have_text(re.compile(r'^UPDATE 1, 1 row \('))
    assert count(edit_file, "SELECT COUNT(*) FROM pk WHERE name = 'b';") == 1
