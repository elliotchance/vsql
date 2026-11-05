# How the rows of a result are shown: types, sorting, a long value and the limit
# on the number of rows.

import re

import pytest
from playwright.sync_api import expect

from conftest import cli

long_value = 'x' * 50 + 'the rest of it'


@pytest.fixture(autouse=True)
def query_tab(ui):
    """query_tab is a tab to run the queries in."""
    ui.new_tab()


def column(ui, number):
    """column is the text of the cells in a column (from 1) of the result."""
    return ui.page.locator(f'main tbody td:nth-child({number})')


def test_numbers_are_fixed_width_and_right_aligned(ui):
    ui.run("SELECT 1 AS a, 1.5 AS b, 'x' AS c FROM \"my <t>\" FETCH FIRST 1 ROW ONLY")
    for cell in [ui.cells.nth(0), ui.cells.nth(1)]:
        expect(cell).to_have_css('text-align', 'right')
        expect(cell).to_have_css('font-family', re.compile('monospace'))
    expect(ui.headers.nth(0)).to_have_css('text-align', 'right')
    expect(ui.cells.nth(2)).to_have_css('text-align', 'left')
    expect(ui.headers.nth(2)).to_have_css('text-align', 'left')


def test_boolean_colors(ui):
    ui.run("SELECT TRUE AS a, FALSE AS b, x = 1 AS c FROM \"my <t>\" WHERE x IS NULL")
    colors = [ui.cells.nth(i).evaluate('e => getComputedStyle(e).color') for i in range(3)]
    assert ui.cells.nth(2).inner_text() == 'UNKNOWN'
    assert len(set(colors)) == 3


def test_nullability(ui, db_file):
    cli(db_file, 'CREATE TABLE n (a INT NOT NULL, b INT, c INT PRIMARY KEY);')
    ui.run('SELECT * FROM n')
    expect(ui.headers.filter(has_text='A').locator('.type')).to_have_text('INTEGER NOT NULL')
    expect(ui.headers.filter(has_text='B').locator('.type')).to_have_text('INTEGER')
    expect(ui.headers.filter(has_text='C').locator('.type')).to_have_text('INTEGER NOT NULL')


def test_nullability_of_outer_join(ui, db_file):
    # The rows of the other table can be NULL, even with NOT NULL on the column.
    cli(db_file, 'CREATE TABLE p (a INT NOT NULL); CREATE TABLE q (b INT NOT NULL); INSERT INTO p (a) VALUES (1);')
    ui.run('SELECT * FROM p LEFT JOIN q ON a = b')
    expect(ui.cells.nth(1)).to_have_text('NULL')
    expect(ui.headers.filter(has_text='B').locator('.type')).to_have_text('INTEGER')


def test_sort(ui, db_file):
    cli(db_file, "CREATE TABLE s (n INT, t VARCHAR(10)); INSERT INTO s (n, t) VALUES (10, 'b'), (9, 'c'), (NULL, 'a'), (100, NULL);")
    ui.run('SELECT * FROM s')
    expect(column(ui, 1)).to_have_text(['10', '9', 'NULL', '100'])

    # Numbers aren't sorted as text, and NULL is last both ways.
    ui.headers.nth(0).click()
    expect(column(ui, 1)).to_have_text(['9', '10', '100', 'NULL'])
    expect(ui.headers.nth(0)).to_have_attribute('aria-sort', 'ascending')
    ui.headers.nth(0).click()
    expect(column(ui, 1)).to_have_text(['100', '10', '9', 'NULL'])
    ui.headers.nth(0).click()
    expect(column(ui, 1)).to_have_text(['10', '9', 'NULL', '100'])
    expect(ui.headers.nth(0)).not_to_have_attribute('aria-sort', re.compile('.'))

    ui.headers.nth(1).click()
    expect(column(ui, 2)).to_have_text(['a', 'b', 'c', 'NULL'])


def test_more_rows_than_shown(ui, db_file):
    values = ', '.join(f'({i})' for i in range(101))
    cli(db_file, f'CREATE TABLE r (x INT); INSERT INTO r (x) VALUES {values};')
    ui.run('SELECT r.x FROM r JOIN r AS s ON r.x = s.x')
    expect(ui.status).to_contain_text('101 rows')
    expect(ui.page.locator('.more-rows')).to_have_count(0)

    ui.run('SELECT r.x FROM r JOIN r AS s ON TRUE')
    expect(ui.status).to_contain_text('10000+ rows')
    expect(ui.page.locator('.more-rows')).to_contain_text('more rows')
    expect(ui.rows).to_have_count(10000)


def test_exactly_as_many_rows_as_shown(ui, db_file):
    values = ', '.join(f'({i})' for i in range(100))
    cli(db_file, f'CREATE TABLE r (x INT); INSERT INTO r (x) VALUES {values};')
    ui.run('SELECT r.x FROM r JOIN r AS s ON TRUE')
    expect(ui.status).to_contain_text('10000 rows')
    expect(ui.page.locator('.more-rows')).to_have_count(0)


def long_table(db_file, ui, key=True):
    primary_key = ' PRIMARY KEY' if key else ''
    cli(db_file, f"CREATE TABLE l (id INT{primary_key}, v VARCHAR(100)); INSERT INTO l (id, v) VALUES (1, '{long_value}'), (2, '{'y' * 50}');")
    ui.run('SELECT * FROM l')


def test_long_value_is_shortened(ui, db_file):
    long_table(db_file, ui)
    expect(ui.cell(0, 'V')).to_contain_text('x' * 50 + '...')
    expect(ui.cell(0, 'V')).not_to_contain_text('the rest')
    expect(ui.cell(0, 'V').locator('button.expand')).to_be_visible()
    # 50 characters isn't long.
    expect(ui.cell(1, 'V')).to_have_text('y' * 50)
    expect(ui.cell(1, 'V').locator('button.expand')).to_have_count(0)


def test_long_value_popup_can_only_be_read(ui, db_file):
    long_table(db_file, ui)
    ui.cell(0, 'V').locator('button.expand').click()
    dialog = ui.page.locator('dialog.cell-value')
    area = dialog.locator('textarea')
    expect(area).to_have_value(long_value)
    expect(area).not_to_be_editable()
    expect(dialog.locator('button.create')).to_be_hidden()
    dialog.locator('button.keep').click()
    expect(dialog).to_be_hidden()


def test_long_value_popup_copies(ui, db_file, context):
    context.grant_permissions(['clipboard-read', 'clipboard-write'])
    long_table(db_file, ui)
    ui.cell(0, 'V').locator('button.expand').click()
    dialog = ui.page.locator('dialog.cell-value')
    dialog.locator('button.copy').click()
    expect(dialog.locator('button.copy')).to_have_text('Copied')
    assert ui.page.evaluate('navigator.clipboard.readText()') == long_value


def test_long_value_changed_in_popup_while_editing(ui, db_file):
    long_table(db_file, ui)
    ui.page.locator('button.edit').click()
    ui.cell(0, 'V').locator('button.expand').click()
    dialog = ui.page.locator('dialog.cell-value')
    area = dialog.locator('textarea')
    expect(area).to_be_editable()
    expect(area).to_have_value(long_value)

    # Cancel keeps the value, without opening the cell.
    area.fill('nope')
    dialog.locator('button.keep').click()
    expect(ui.page.locator('button.edit')).to_have_text('Cancel edit')
    expect(ui.cell(0, 'V').locator('input')).to_have_count(0)

    ui.cell(0, 'V').locator('button.expand').click()
    expect(area).to_have_value(long_value)
    area.fill('z' * 60)
    dialog.locator('button.create').click()
    expect(ui.cell(0, 'V')).to_contain_text('z' * 50 + '...')
    ui.page.locator('button.edit').click()
    expect(ui.page.locator('button.edit')).to_have_text('Edit...')
    expect(ui.cell(0, 'V')).to_contain_text('z' * 50 + '...')
    assert 'z' * 60 in cli(db_file, 'SELECT v FROM l WHERE id = 1;')


def test_long_value_is_not_changed_by_saving_another_cell(ui, db_file):
    # The value that's saved isn't the one that's shown.
    long_table(db_file, ui)
    ui.page.locator('button.edit').click()
    ui.cell(1, 'V').click()
    ui.cell(1, 'V').locator('input').fill('short')
    ui.cell(1, 'V').locator('input').press('Enter')
    expect(ui.page.locator('button.edit')).to_have_text('Save 1 change')
    ui.page.locator('button.edit').click()
    expect(ui.page.locator('button.edit')).to_have_text('Edit...')
    expect(ui.cell(1, 'V')).to_have_text('short')
    assert long_value in cli(db_file, 'SELECT v FROM l WHERE id = 1;')


def test_cannot_sort_while_editing(ui, db_file):
    long_table(db_file, ui)
    ui.page.locator('button.edit').click()
    ui.headers.filter(has_text='ID').click()
    expect(ui.headers.filter(has_text='ID')).not_to_have_attribute('aria-sort', re.compile('.'))
    ui.page.locator('button.edit').click()
    ui.headers.filter(has_text='ID').click()
    expect(ui.headers.filter(has_text='ID')).to_have_attribute('aria-sort', 'ascending')
