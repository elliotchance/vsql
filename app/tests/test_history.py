# The history of a tab: each query that's run is kept with its outcome, and can
# be put back in the editor.

import re

from playwright.sync_api import expect

from conftest import cli, count
from pages import AppPage


def test_no_history(ui):
    # A tab that hasn't run anything has no history to show.
    ui.new_tab()
    ui.editor.fill('VALUES 1')
    expect(ui.history_button).to_have_count(0)


def test_outcomes(ui):
    # The latest is first, with the number of rows, the message of a statement
    # or the error, and when it was run.
    ui.new_tab()
    ui.run('VALUES 1')
    ui.run('CREATE TABLE h (x INT)')
    ui.run('SELECT * FROM nope')
    ui.history_button.click()
    expect(ui.history).to_be_visible()
    expect(ui.history_entries.locator('pre')).to_have_text(
        ['SELECT * FROM nope', 'CREATE TABLE h (x INT)', 'VALUES 1'])
    meta = ui.history_entries.locator('.meta')
    date = r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
    expect(meta.nth(0)).to_have_text(re.compile(date + '.* · .*no such table'))
    expect(meta.nth(1)).to_have_text(re.compile(date + '.* · CREATE TABLE 1$'))
    expect(meta.nth(2)).to_have_text(re.compile(date + '.* · 1 row$'))
    expect(ui.history_entries.locator('pre .kw').first).to_have_text('SELECT')

    ui.history.get_by_role('button', name='×').click()
    expect(ui.history).to_be_hidden()


def test_choose(ui, db_file):
    # Choosing a query puts it in the editor without running it.
    ui.new_tab()
    ui.run('VALUES 1')
    ui.run('VALUES 2')
    ui.history_button.click()
    ui.history_entries.nth(1).click()
    expect(ui.history).to_be_hidden()
    expect(ui.editor).to_have_value('VALUES 1')
    expect(ui.editor).to_be_focused()
    expect(ui.page.locator('.editor pre .kw')).to_have_text('VALUES')
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.history;') == 2


def test_search_popup(ui):
    # The popup of a tab is searched as it's typed, and shows all of the queries
    # again the next time it's opened.
    ui.new_tab()
    ui.run('VALUES 1')
    ui.run('SELECT * FROM nope')
    ui.history_button.click()
    expect(ui.history_search).to_be_focused()
    queries = ui.history_entries.locator('pre')
    expect(queries).to_have_text(['SELECT * FROM nope', 'VALUES 1'])

    ui.history_search.fill('values')
    expect(queries).to_have_text(['VALUES 1'])
    ui.history_search.fill('missing')
    expect(queries).to_have_count(0)
    expect(ui.page.locator('.history-no-match')).to_be_visible()

    ui.history.get_by_role('button', name='×').click()
    ui.history_button.click()
    expect(ui.history_search).to_have_value('')
    expect(queries).to_have_text(['SELECT * FROM nope', 'VALUES 1'])

    # Choosing a query still puts it in the editor.
    ui.history_search.fill('values')
    ui.history_entries.first.click()
    expect(ui.editor).to_have_value('VALUES 1')


def test_each_tab(ui, db_file):
    # Each tab has its own history, and closing a tab removes its history.
    ui.new_tab()
    ui.run('VALUES 1')
    first = ui.tab_id
    ui.new_tab()
    expect(ui.history_button).to_have_count(0)
    ui.run('VALUES 2')
    ui.history_button.click()
    expect(ui.history_entries.locator('pre')).to_have_text(['VALUES 2'])
    ui.history.get_by_role('button', name='×').click()
    second = ui.tab_id
    assert first != second
    first_id, second_id = first.split(':')[1], second.split(':')[1]

    ui.page.request.post(ui.app.url, form={'tab': second, 'close': second})
    assert count(db_file, f'SELECT COUNT(*) FROM vsql_app.history WHERE tab_id = {second_id};') == 0
    assert count(db_file, f'SELECT COUNT(*) FROM vsql_app.history WHERE tab_id = {first_id};') == 1


def test_limit(ui, db_file):
    # Only the latest 100 queries of a tab are kept.
    ui.new_tab()
    ui.run('VALUES 0')
    tab = ui.tab_id
    for i in range(1, 101):
        ui.page.request.post(ui.app.url, form={'tab': tab, 'sql': f'VALUES {i}'})
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.history;') == 100
    assert re.search(r'^VALUES 1 *$', cli(db_file, 'SELECT query_text FROM vsql_app.history ORDER BY id FETCH FIRST 1 ROW ONLY;'), re.MULTILINE)


def test_existing_file(ui, db_file, start_app):
    # A file from before the history gets the table when it's opened.
    cli(db_file, 'DROP TABLE vsql_app.history;')
    start_app(db_file)
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.history;') == 0


def test_history_tab(ui, db_file):
    # The sidebar shows the queries of all of the tabs in a tab of its own. There
    # is only one, and it has no editor.
    ui.new_tab()
    ui.run('VALUES 1')
    ui.new_tab()
    ui.run('SELECT * FROM nope')
    ui.history_nav.click()
    expect(ui.active_tab).to_have_text(re.compile('^Query History'))
    expect(ui.editor).to_have_count(0)
    entries = ui.page.locator('main .history-list li button')
    expect(entries.locator('pre')).to_have_text(['SELECT * FROM nope', 'VALUES 1'])
    expect(entries.nth(0).locator('.failed')).to_contain_text('no such table')
    expect(entries.nth(1).locator('.meta')).to_have_text(re.compile('1 row$'))
    expect(entries.locator('pre .kw').first).to_have_text('SELECT')

    tabs = ui.tab_bar.count()
    ui.tab('VALUES 1').click()
    ui.history_nav.click()
    expect(ui.tab_bar).to_have_count(tabs)
    expect(ui.active_tab).to_have_text(re.compile('^Query History'))
    assert count(db_file, "SELECT COUNT(*) FROM vsql_app.tabs WHERE tab_type = 'HISTORY';") == 1

    # Choosing a query opens it in a new tab, without running it.
    entries.nth(1).click()
    expect(ui.tab_bar).to_have_count(tabs + 1)
    expect(ui.editor).to_have_value('VALUES 1')
    expect(ui.empty).to_have_text('Run to see the result.')
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.history;') == 2

    # It's kept when the file is opened again, and can be closed.
    ui.reload()
    ui.history_nav.click()
    ui.close_tab(ui.active_tab)
    expect(ui.tab_bar).to_have_count(tabs)
    assert count(db_file, "SELECT COUNT(*) FROM vsql_app.tabs WHERE tab_type = 'HISTORY';") == 0


def test_history_tab_empty(ui):
    # It can be opened without any tabs or queries, there's nothing to search.
    ui.history_nav.click()
    expect(ui.empty).to_have_text('No queries have been run.')
    expect(ui.history_search).to_have_count(0)


def test_search(ui):
    # The history tab is searched as it's typed, in the SQL and its outcome,
    # ignoring case.
    ui.new_tab()
    ui.run('VALUES 1')
    ui.run('SELECT * FROM nope')
    ui.history_nav.click()
    expect(ui.history_search).to_be_focused()
    entries = ui.page.locator('main .history-list li:not([hidden]) pre')
    no_match = ui.page.locator('.history-no-match')
    expect(entries).to_have_text(['SELECT * FROM nope', 'VALUES 1'])
    expect(no_match).to_be_hidden()

    ui.history_search.fill('values')
    expect(entries).to_have_text(['VALUES 1'])
    ui.history_search.fill('no such table')
    expect(entries).to_have_text(['SELECT * FROM nope'])
    ui.history_search.fill('missing')
    expect(entries).to_have_count(0)
    expect(no_match).to_be_visible()

    ui.history_search.fill('')
    expect(entries).to_have_text(['SELECT * FROM nope', 'VALUES 1'])
    expect(no_match).to_be_hidden()


def test_each_file(page, db_file, make_file, start_app):
    # Each file has its own VSQL_APP, tabs and history. The tab bar has the tabs of
    # all of them.
    other = make_file('other.vsql', 'CREATE TABLE people (id INT PRIMARY KEY);')
    ui = AppPage(page, start_app(db_file, other))
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.history;') == 0
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.tabs;') == 0

    # A table opened from a file is a tab of that file, and runs in it.
    ui.sidebar_table('PEOPLE', 'other').click()
    expect(ui.catalog_tabs('other')).to_have_count(1)
    expect(ui.catalog_tabs('db')).to_have_count(0)
    ui.run('SELECT * FROM people')
    expect(ui.status).to_have_text(re.compile(r'^0 rows \('))
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.history;') == 2
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.history;') == 0
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
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.history;') == 1
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.history;') == 2

    # There's one active tab, which is kept when the app is opened again.
    ui.tab_bar.nth(1).locator('button').first.click()
    assert ui.tab_id == 'other:1'
    ui.open(ui.app)
    assert ui.tab_id == 'other:1'
    expect(ui.active_tab).to_have_count(1)

    # The history of each file is shown separately, in its own tab.
    entries = ui.page.locator('main .history-list li button')
    ui.catalog_history_nav('db').click()
    expect(ui.active_tab).to_have_text(re.compile(r'^Query History \(db\)'))
    expect(entries.locator('pre')).to_have_text(['SELECT * FROM foo.bar'])
    ui.catalog_history_nav('other').click()
    expect(ui.active_tab).to_have_text(re.compile(r'^Query History \(other\)'))
    expect(entries.locator('pre')).to_have_text(['SELECT * FROM people', 'SELECT * FROM PUBLIC.PEOPLE'])

    # A query opens in a tab of that file.
    tabs = ui.catalog_tabs('other').count()
    entries.nth(0).click()
    expect(ui.editor).to_have_value('SELECT * FROM people')
    expect(ui.catalog_tabs('other')).to_have_count(tabs + 1)

    # Closing the tab of one file leaves the tab with the same id in the other.
    ui.page.request.post(ui.app.url, form={'tab': ui.tab_id, 'close': 'other:1'})
    assert count(other, 'SELECT COUNT(*) FROM vsql_app.tabs WHERE id = 1;') == 0
    assert count(db_file, 'SELECT COUNT(*) FROM vsql_app.tabs WHERE id = 1;') == 1
