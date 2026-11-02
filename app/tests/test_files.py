# More than one file: each has its own VSQL_APP and tabs, the tab bar has the tabs
# of all of them.

import re

from playwright.sync_api import expect

from conftest import count
from pages import AppPage


def test_each_file(page, db_file, make_file, start_app):
    other = make_file('other.vsql', 'CREATE TABLE people (id INT PRIMARY KEY);')
    ui = AppPage(page, start_app(db_file, other))
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 0

    # A table opened from a file is a tab of that file, and runs in it.
    ui.sidebar_table('PEOPLE', 'other').click()
    expect(ui.catalog_tabs('other')).to_have_count(1)
    expect(ui.catalog_tabs('db')).to_have_count(0)
    ui.run('SELECT * FROM people')
    expect(ui.status).to_have_text(re.compile(r'^0 rows \('))
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 1
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 0

    # A new tab in the tab bar is in the same file, or the sidebar can add a tab
    # to a file. The ids of the tabs are the same in each file.
    ui.new_tab()
    expect(ui.catalog_tabs('other')).to_have_count(2)
    ui.new_catalog_tab('db')
    expect(ui.catalog_tabs('db')).to_have_count(1)
    expect(ui.tab_bar).to_have_count(3)
    assert ui.tab_id == 'db:1'
    ui.run('SELECT * FROM foo.bar')
    expect(ui.status).to_have_text(re.compile(r' rows? \('))

    # There's one active tab, which is kept when the app is opened again.
    ui.tab_bar.nth(1).locator('button').first.click()
    assert ui.tab_id == 'other:1'
    ui.open(ui.app)
    assert ui.tab_id == 'other:1'
    expect(ui.active_tab).to_have_count(1)

    # Each tab has the colored dot of its file, which is next to the file in the
    # sidebar.
    def color(dot):
        return dot.evaluate('e => getComputedStyle(e).backgroundColor')

    db_dot = color(ui.page.locator('details[data-folder="catalog:db"] > summary .dot'))
    other_dot = color(ui.page.locator('details[data-folder="catalog:other"] > summary .dot'))
    assert db_dot != other_dot
    assert color(ui.tab_bar.nth(0).locator('.dot')) == db_dot
    assert color(ui.tab_bar.nth(1).locator('.dot')) == other_dot
    assert color(ui.tab_bar.nth(2).locator('.dot')) == other_dot

    # Closing the tab of one file leaves the tab with the same id in the other.
    ui.page.request.post(ui.app.url, form={'tab': ui.tab_id, 'close': 'other:1'})
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.tabs WHERE id = 1;') == 0
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.tabs WHERE id = 1;') == 1
