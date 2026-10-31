# The tabs: adding, switching to and closing them, in the tab bar and the
# sidebar.

import re

from playwright.sync_api import expect

from conftest import count
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
    ui.sidebar_table('my <t>').click()
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
    ui.sidebar_table('my <t>').click()
    ui.new_tab()
    ui.run('INSERT INTO foo.bar (y) VALUES (TRUE)')
    ui.editor.fill('SELECT * FROM foo.bar')
    ui.tab('SELECT * FROM PUBLIC."my <t>"').click()
    expect(ui.editor).to_have_value('SELECT * FROM PUBLIC."my <t>"')
    expect(ui.cells.nth(1)).to_have_text('a&b')
    expect(ui.sidebar_tabs).to_have_text(titles('SELECT * FROM PUBLIC."my <t>"', 'INSERT INTO foo.bar (y) VALUES...'))
    expect(ui.sidebar_tabs).to_have_class(['active', ''])

    ui.sidebar_tab('INSERT INTO foo.bar (y) VALUES...').click()
    expect(ui.editor).to_have_value('SELECT * FROM foo.bar')
    expect(ui.status).to_have_text(re.compile(r'^INSERT 1 \('))
    assert count(db_file, 'SELECT COUNT(*) FROM foo.bar;') == 1


def test_close_tabs(ui, db_file):
    # Closing the active tab activates the first tab, and closing the last tab
    # leaves no tab.
    ui.new_tab()
    ui.sidebar_table('my <t>').click()
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
