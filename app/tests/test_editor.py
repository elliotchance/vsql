# The SQL editor of a tab: highlighting, running and the result.

import re

from playwright.sync_api import expect

from conftest import count
from pages import titles


def test_choose_table(ui):
    # Choosing a table opens a new tab that runs SELECT * on it.
    ui.sidebar_table('my <t>').click()
    expect(ui.page).to_have_url(ui.app.url)
    expect(ui.active_tab).to_have_text(re.compile(r'^SELECT \* FROM PUBLIC\."my <t>"'))
    expect(ui.editor).to_have_value('SELECT * FROM PUBLIC."my <t>"')
    expect(ui.status).to_have_text(re.compile(r'^2 rows \(\d+ ms\)$'))
    expect(ui.headers).to_have_text(['XINTEGER', 'SCHARACTER VARYING(10)'])
    expect(ui.rows.nth(0).locator('td')).to_have_text(['1', 'a&b'])
    expect(ui.rows.nth(1).locator('td.null')).to_have_text(['NULL', 'NULL'])

    # The sidebar is on every page, it lists the tab.
    expect(ui.sidebar_tabs).to_have_text(titles('SELECT * FROM PUBLIC."my <t>"'))
    expect(ui.sidebar_tabs).to_have_class(['active'])


def test_highlight(ui):
    # The editor colors reserved words (but not non-reserved words like NAME),
    # strings, numbers and comments as it's typed.
    ui.new_tab()
    ui.editor.fill("select name, 'it''s', 1.5e3 FROM t -- done")
    expect(ui.highlighted.locator('.kw')).to_have_text(['select', 'FROM'])
    expect(ui.highlighted.locator('.str')).to_have_text(["'it''s'"])
    expect(ui.highlighted.locator('.num')).to_have_text(['1.5e3'])
    expect(ui.highlighted.locator('.com')).to_have_text(['-- done'])


def test_run(ui, db_file):
    # Running shows the result of the last statement and sets the title.
    ui.new_tab()
    ui.run('INSERT INTO foo.bar (y) VALUES (TRUE); SELECT y, 1 + 2 AS z FROM foo.bar')
    expect(ui.active_tab).to_have_text(re.compile(r'^INSERT INTO foo\.bar \(y\) VALUES\.\.\.'))
    expect(ui.status).to_have_text(re.compile(r'^1 row \('))
    expect(ui.headers).to_have_text(['YBOOLEAN', 'ZSMALLINT'])
    expect(ui.cells).to_have_text(['TRUE', '3'])

    # Ctrl+Enter (or Cmd+Enter) runs it too.
    ui.editor.fill('INSERT INTO foo.bar (y) VALUES (FALSE)')
    ui.editor.press('Control+Enter')
    expect(ui.status).to_have_text(re.compile(r'^INSERT 1 \('))
    ui.editor.press('Meta+Enter')
    expect(ui.status).to_have_text(re.compile(r'^INSERT 1 \('))
    assert count(db_file, 'SELECT COUNT(*) FROM foo.bar;') == 3


def test_error(ui):
    # An error is shown on the page.
    ui.new_tab()
    ui.run('SELECT * FROM nope')
    expect(ui.error).to_contain_text('no such table')
    expect(ui.status).to_have_text(re.compile(r'^Error \('))


def test_explain(ui):
    # Explain runs the SQL with EXPLAIN in front of it, the SQL of the tab
    # isn't changed.
    ui.new_tab()
    ui.editor.fill('SELECT * FROM foo.bar WHERE y')
    ui.page.get_by_role('button', name='Explain').click()
    expect(ui.editor).to_have_value('SELECT * FROM foo.bar WHERE y')
    expect(ui.active_tab).to_have_text(re.compile(r'^SELECT \* FROM foo\.bar WHERE y'))
    expect(ui.headers).to_have_text(['EXPLAINCHARACTER VARYING'])
    expect(ui.cells.first).to_have_text('TABLE "db".FOO.BAR (Y BOOLEAN)')
    expect(ui.status).to_have_text(re.compile(r'^3 rows \('))

