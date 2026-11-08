# The SQL editor of a tab: highlighting, running and the result.

import re

from playwright.sync_api import expect

from conftest import cli, count
from pages import AppPage, titles


def test_choose_table(ui):
    # Choosing a table opens a new tab that runs SELECT * on it.
    ui.select_table('my <t>')
    expect(ui.page).to_have_url(ui.app.url)
    expect(ui.active_tab).to_have_text(re.compile(r'^SELECT \* FROM PUBLIC\."my <t>"'))
    expect(ui.editor).to_have_value('SELECT * FROM PUBLIC."my <t>"')
    expect(ui.status).to_have_text(re.compile(r'^2 rows \(\d+ ms\)$'))
    expect(ui.headers).to_have_text(['🟦XINTEGER', '🟩SCHARACTER VARYING(10)'])
    expect(ui.rows.nth(0).locator('td')).to_have_text(['1', 'a&b'])
    expect(ui.rows.nth(1).locator('td.null')).to_have_text(['NULL', 'NULL'])

    # The sidebar is on every page, it lists the tab.
    expect(ui.sidebar_tabs).to_have_text(titles('SELECT * FROM PUBLIC."my <t>"'))
    expect(ui.sidebar_tab_rows).to_have_class(['active'])


def test_highlight(ui):
    # The editor colors reserved words (but not non-reserved words like NAME),
    # strings, numbers and comments as it's typed.
    ui.new_tab()
    ui.editor.fill("select name, 'it''s', 1.5e3 FROM t -- done")
    expect(ui.highlighted.locator('.kw')).to_have_text(['select', 'FROM'])
    expect(ui.highlighted.locator('.str')).to_have_text(["'it''s'"])
    expect(ui.highlighted.locator('.num')).to_have_text(['1.5e3'])
    expect(ui.highlighted.locator('.com')).to_have_text(['-- done'])


def test_highlight_extension_keywords(ui):
    # The words of vsql extensions are colored, but they aren't reserved so a
    # name doesn't need quotes.
    ui.new_tab()
    ui.editor.fill("select name from t limit 1")
    expect(ui.highlighted.locator('.kw')).to_have_text(['select', 'from', 'limit'])
    assert ui.page.evaluate("toName('limit')") == 'LIMIT'
    assert ui.page.evaluate("toName('select')") == '"SELECT"'


def test_run(ui, db_file):
    # Running shows the result of the last statement and sets the title.
    ui.new_tab()
    ui.run('INSERT INTO foo.bar (y) VALUES (TRUE); SELECT y, 1 + 2 AS z FROM foo.bar')
    expect(ui.active_tab).to_have_text(re.compile(r'^INSERT INTO foo\.bar \(y\) VALUES\.\.\.'))
    expect(ui.status).to_have_text(re.compile(r'^1 row \('))
    expect(ui.headers).to_have_text(['🟪YBOOLEAN', '🟦ZSMALLINT'])
    expect(ui.cells).to_have_text(['TRUE', '3'])

    # The title is the SQL on one line, before it's cut short.
    ui.run('SELECT\n    y\n\nFROM foo.bar')
    expect(ui.active_tab).to_have_text(re.compile(r'^SELECT y FROM foo\.bar'))

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
    # The plan is lines of text, not a table.
    expect(ui.headers).to_have_count(0)
    plan = ui.page.locator('pre.explain')
    expect(plan).to_contain_text('TABLE "db".FOO.BAR (Y BOOLEAN)')
    assert len(plan.inner_text().splitlines()) == 3
    # The first term of each line is highlighted.
    expect(plan.locator('.kw')).to_have_text(['TABLE', 'WHERE', 'EXPR'])
    expect(ui.status).to_have_text(re.compile(r'^3 rows \('))


def test_explain_keywords(page, db_file, start_app):
    # The range of a PRIMARY KEY (or an INDEX) and the condition of a join are
    # highlighted too, but not the same words in a name, a string or the
    # columns.
    cli(db_file, 'CREATE TABLE "a ON b" (" RANGE " INT PRIMARY KEY, x VARCHAR(10)); CREATE TABLE c (y VARCHAR(10));')
    ui = AppPage(page, start_app(db_file))
    ui.new_tab()
    ui.editor.fill("""SELECT * FROM "a ON b" WHERE " RANGE " = 3 AND x <> ' RANGE '""")
    ui.page.get_by_role('button', name='Explain').click()
    plan = ui.page.locator('pre.explain')
    expect(plan.locator('.kw')).to_have_text(['PRIMARY KEY', 'RANGE', 'WHERE', 'EXPR'])
    expect(plan).to_contain_text('PRIMARY KEY "db".PUBLIC."a ON b" (" RANGE " INTEGER NOT NULL, X CHARACTER VARYING(10)) RANGE " RANGE " = 3')

    ui.editor.fill("""SELECT * FROM "a ON b" JOIN c ON c.y = ' ON '""")
    ui.page.get_by_role('button', name='Explain').click()
    expect(plan.locator('.kw')).to_have_text(['$1:', 'TABLE', '$2:', 'TABLE', 'INNER JOIN', 'ON', 'EXPR'])

