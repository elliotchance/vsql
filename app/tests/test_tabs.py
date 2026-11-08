# The tabs: adding, switching to and closing them, in the tab bar and the
# sidebar.

import re

from playwright.sync_api import expect

from conftest import cli, count
from pages import titles

show_tables_sql = 'SELECT * FROM INFORMATION_SCHEMA.TABLES'


def test_no_tabs(ui, db_file):
    # The first time there are no tabs (VSQL_APP.TABS is empty), so there's no
    # editor.
    expect(ui.empty).to_have_text('Choose a table, or use + to add a tab.')
    expect(ui.editor).to_have_count(0)
    expect(ui.tab_bar).to_have_count(0)
    expect(ui.new_tab_button).to_be_visible()
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 0


def test_new_tab(ui):
    # Adding a tab saves the SQL of the current tab first (but not its title,
    # that is only set when it's run) and makes the new tab active. A new tab
    # shows the tables.
    ui.select_table('my <t>')
    ui.editor.fill('SELECT * FROM "PUBLIC"."my <t>"')
    ui.new_tab()
    expect(ui.tab_bar).to_have_count(2)
    expect(ui.active_tab).to_have_text(re.compile(r'^SELECT \* FROM INFORMATION_SCHE\.\.\.'))
    expect(ui.editor).to_have_value(show_tables_sql)
    expect(ui.empty).to_have_text('Run to see the result.')

    ui.tab('SELECT * FROM PUBLIC."my <t>"').click()
    expect(ui.editor).to_have_value('SELECT * FROM "PUBLIC"."my <t>"')


def test_switch_tabs(ui, db_file):
    # Switching tabs saves the SQL, but doesn't run either tab. The last result
    # of the tab is shown. The sidebar lists the tabs (with the active one) to
    # go to them, like the tab bar.
    ui.select_table('my <t>')
    ui.new_tab()
    ui.run('INSERT INTO foo.bar (y) VALUES (TRUE)')
    ui.editor.fill('SELECT * FROM foo.bar')
    ui.tab('SELECT * FROM PUBLIC."my <t>"').click()
    expect(ui.editor).to_have_value('SELECT * FROM PUBLIC."my <t>"')
    expect(ui.cells.nth(1)).to_have_text('a&b')
    expect(ui.sidebar_tabs).to_have_text(titles('SELECT * FROM PUBLIC."my <t>"', 'INSERT INTO foo.bar (y) VALUES...'))
    expect(ui.sidebar_tab_rows).to_have_class(['active', ''])

    ui.sidebar_tab('INSERT INTO foo.bar (y) VALUES...').click()
    expect(ui.editor).to_have_value('SELECT * FROM foo.bar')
    expect(ui.status).to_have_text(re.compile(r'^INSERT 1 \('))
    assert count(db_file, 'SELECT COUNT(*) FROM foo.bar;') == 1


def test_close_tabs(ui, db_file):
    # Closing the active tab activates the first tab, and closing the last tab
    # leaves no tab.
    ui.new_tab()
    ui.select_table('my <t>')
    ui.new_tab()
    ui.tab('SELECT * FROM PUBLIC."my <t>"').click()
    ui.close_tab(ui.active_tab)
    expect(ui.tab_bar).to_have_count(2)
    expect(ui.active_tab).to_have_text(re.compile(r'^SELECT \* FROM INFORMATION_SCHE'))
    expect(ui.tab_bar.nth(0)).to_have_class(re.compile('active'))

    # Closing a tab that isn't active leaves the active tab.
    ui.close_tab(ui.tab_bar.nth(1))
    expect(ui.tab_bar).to_have_count(1)
    expect(ui.tab_bar.nth(0)).to_have_class(re.compile('active'))

    ui.close_tab(ui.tab_bar.nth(0))
    expect(ui.empty).to_have_text('Choose a table, or use + to add a tab.')
    expect(ui.tab_bar).to_have_count(0)
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 0


def test_close_from_sidebar(ui, db_file):
    # The menu of a tab in the sidebar closes it.
    ui.new_tab()
    ui.run('VALUES 1')
    ui.new_tab()
    ui.run('VALUES 2')
    expect(ui.tab_bar).to_have_count(2)
    menu = ui.tab_menu('VALUES 1')
    menu.get_by_role('button', name='Close').click()
    expect(ui.tab_bar).to_have_count(1)
    expect(ui.active_tab).to_have_text(re.compile('^VALUES 2'))
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 1

    # So does the x next to its menu.
    ui.new_tab()
    ui.run('VALUES 3')
    expect(ui.tab_bar).to_have_count(2)
    close = ui.sidebar_tab_close('VALUES 2')
    expect(close).to_have_attribute('aria-label', 'Close VALUES 2')
    close.click()
    expect(ui.tab_bar).to_have_count(1)
    expect(ui.active_tab).to_have_text(re.compile('^VALUES 3'))
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 1


def schema_select(ui):
    return ui.page.locator('select[name="query_schema"]')


def test_query_schema(ui, db_file):
    # A tab has the schemas of its file next to the file, and runs in PUBLIC unless
    # another one is chosen.
    ui.new_tab()
    expect(ui.page.locator('.actions .catalog + select')).to_have_value('PUBLIC')
    expect(schema_select(ui).locator('option')).to_contain_text(['FOO', 'PUBLIC'])

    # The SQL doesn't need the schema, and it's only in the tab.
    schema_select(ui).select_option('FOO')
    ui.run('SELECT CURRENT_SCHEMA FROM (VALUES 1) AS t')
    expect(ui.page.locator('main table.result td').first).to_have_text('FOO')
    expect(ui.editor).to_have_value('SELECT CURRENT_SCHEMA FROM (VALUES 1) AS t')
    expect(schema_select(ui)).to_have_value('FOO')
    ui.run('SELECT * FROM bar')
    expect(ui.error).to_have_count(0)
    assert count(db_file, "SELECT COUNT(*) FROM vsql_app.history WHERE query_text LIKE '%SET SCHEMA%';") == 0

    # Explain runs in it too.
    ui.page.get_by_role('button', name='Explain').click()
    expect(ui.page.locator('main pre.explain')).to_contain_text('FOO')

    # It's kept with the tab.
    ui.new_tab()
    expect(schema_select(ui)).to_have_value('PUBLIC')
    ui.run('SELECT * FROM bar')
    expect(ui.error).to_be_visible()
    ui.tab('SELECT * FROM bar').first.click()
    expect(schema_select(ui)).to_have_value('FOO')
    ui.reload()
    expect(schema_select(ui)).to_have_value('FOO')


def test_query_schema_is_gone(ui, db_file):
    # A schema that's dropped, or that was never valid, is just PUBLIC.
    cli(db_file, 'CREATE SCHEMA gone;')
    ui.reload()
    ui.new_tab()
    schema_select(ui).select_option('GONE')
    ui.run('SELECT CURRENT_SCHEMA FROM (VALUES 1) AS t')
    expect(ui.page.locator('main table.result td').first).to_have_text('GONE')

    cli(db_file, 'DROP SCHEMA gone CASCADE;')
    ui.reload()
    expect(schema_select(ui)).to_have_value('PUBLIC')
    ui.page.get_by_role('button', name=re.compile('^Run')).click()
    expect(ui.page.locator('main table.result td').first).to_have_text('PUBLIC')

    cli(db_file, """UPDATE vsql_app.tabs SET payload = '{"query_text":"SELECT CURRENT_SCHEMA FROM (VALUES 1) AS t","schema":"nope"}' WHERE active = TRUE;""")
    ui.reload()
    expect(schema_select(ui)).to_have_value('PUBLIC')
    ui.page.get_by_role('button', name=re.compile('^Run')).click()
    expect(ui.page.locator('main table.result td').first).to_have_text('PUBLIC')


def test_query_schema_edit(ui, db_file):
    # After the rows are changed the SQL runs again, in the same schema.
    cli(db_file, "CREATE TABLE foo.items (id INT NOT NULL PRIMARY KEY, name VARCHAR(20));\nINSERT INTO foo.items (id, name) VALUES (1, 'a');")
    ui.reload()
    ui.new_tab()
    schema_select(ui).select_option('FOO')
    ui.run('SELECT * FROM items')
    ui.edit_button.click()
    ui.edit(0, 'NAME', 'b')
    ui.edit_button.click()
    expect(ui.page.locator('.status')).to_contain_text('Saved 1 change')
    expect(ui.cell(0, 'NAME')).to_have_text('b')
    expect(schema_select(ui)).to_have_value('FOO')
