# The sidebar: the version, each catalog with its tables under their schema,
# and the tabs. It can be collapsed and resized, and a table dropped.

import re

from playwright.sync_api import expect

from conftest import cli
from pages import AppPage


def test_sidebar(ui):
    # The sidebar has the version, and the catalog with its tabs and its tables
    # under their schema (including VSQL_APP).
    expect(ui.brand).to_have_text(re.compile(r'^vsql v\d+\.\d+\.\d+$'))
    expect(ui.sections).to_have_text([re.compile('db$')])
    for schema, table in [('FOO', 'FOO.BAR'), ('PUBLIC', 'PUBLIC."my <t>"')]:
        expect(ui.schema('db', schema).locator('summary .count')).to_have_text('1')
        expect(ui.schema('db', schema).locator('li > button')).to_have_attribute('value', table)
    expect(ui.schema('db', 'VSQL_APP').locator('summary .count')).to_have_text('2')
    expect(ui.schema('db', 'VSQL_APP').locator('button').nth(0)).to_have_attribute('value', 'VSQL_APP.HISTORY')
    expect(ui.schema('db', 'VSQL_APP').locator('button').nth(1)).to_have_attribute('value', 'VSQL_APP.TABS')
    expect(ui.sidebar_table('my <t>')).to_have_attribute('title', 'SELECT * FROM PUBLIC."my <t>"')


def test_sidebar_is_remembered(ui):
    # A heading or schema can be collapsed, and the sidebar resized (a
    # double-click goes back to the default width), which the browser
    # remembers.
    ui.schema('db', 'FOO').locator('> summary').click()
    expect(ui.schema('db', 'FOO')).not_to_have_attribute('open', '')
    ui.folder('tabs:db').locator('> summary').click()

    default_width = ui.sidebar_width
    ui.resize_sidebar(400)
    width = ui.sidebar_width
    assert abs(width - 400) < 10

    ui.reload()
    expect(ui.schema('db', 'FOO')).not_to_have_attribute('open', '')
    expect(ui.folder('tabs:db')).not_to_have_attribute('open', '')
    expect(ui.schema('db', 'PUBLIC')).to_have_attribute('open', '')
    assert ui.sidebar_width == width

    ui.resizer.dblclick()
    ui.reload()
    assert ui.sidebar_width == default_width


def test_catalogs(page, db_file, make_file, start_app):
    # Other files are attached as catalogs, each with its own heading. A table
    # is queried without its catalog, since its tab runs in that catalog.
    other_file = make_file('other.vsql', 'CREATE TABLE t (x INT);')
    ui = AppPage(page, start_app(db_file, other_file))
    expect(ui.sections).to_have_text([re.compile('db$'), re.compile('other$')])
    expect(ui.sidebar_table('T', catalog='other')).to_have_attribute('value', 'PUBLIC.T')
    expect(ui.sidebar_table('BAR', schema='FOO')).to_have_attribute('value', 'FOO.BAR')
    ui.sidebar_table('T', catalog='other').click()
    expect(ui.editor).to_have_value('SELECT * FROM PUBLIC.T')
    expect(ui.tab_catalog).to_have_text('other')
    expect(ui.status).to_have_text(re.compile(r'^0 rows \('))


def test_drop_table(ui, db_file):
    # The menu of a table drops it, once it's confirmed. Cancel (or Escape)
    # doesn't drop it.
    ui.table_menu('BAR', schema='FOO').get_by_role('button', name='Drop table').click()
    expect(ui.confirm_sql).to_have_text('DROP TABLE FOO.BAR')
    expect(ui.confirm.get_by_role('button', name='Run')).to_have_class('delete')
    ui.confirm.get_by_role('link', name='Cancel').click()
    expect(ui.confirm).to_have_count(0)
    expect(ui.sidebar_table('BAR', schema='FOO')).to_have_count(1)

    ui.table_menu('BAR', schema='FOO').get_by_role('button', name='Drop table').click()
    ui.run_change()
    expect(ui.confirm).to_have_count(0)
    expect(ui.sidebar_table('BAR', schema='FOO')).to_have_count(0)
    expect(ui.schema('db', 'FOO').locator('li')).to_have_text(['There are no tables.'])
    assert 'BAR' not in cli(db_file, 'SELECT table_name FROM INFORMATION_SCHEMA.TABLES;')

    # It works from a tab too, which is shown again with its SQL.
    ui.new_tab()
    ui.editor.fill('SELECT 1')
    ui.table_menu('my <t>').get_by_role('button', name='Drop table').click()
    expect(ui.confirm_sql).to_have_text('DROP TABLE PUBLIC."my <t>"')
    expect(ui.editor).to_have_value('SELECT 1')
    ui.run_change()
    expect(ui.sidebar_table('my <t>')).to_have_count(0)


def test_indexes(page, db_file, start_app):
    # The indexes of a table are under it, with their columns. The menu of an
    # index drops it, once it's confirmed.
    cli(db_file, 'CREATE TABLE t (x INT, y INT); CREATE INDEX t_y ON t (y DESC, x); CREATE INDEX t_x ON t (x); CREATE INDEX "my <i>" ON foo.bar (y);')
    ui = AppPage(page, start_app(db_file))
    expect(ui.sidebar_indexes('T')).to_have_text([re.compile(r'T_X \(X\)$'), re.compile(r'T_Y \(Y DESC, X\)$')])
    expect(ui.sidebar_indexes('T').nth(1)).to_have_attribute(
        'title', 'CREATE INDEX "T_Y" ON "PUBLIC"."T" ("Y" DESC, "X");')
    expect(ui.sidebar_indexes('my <t>')).to_have_count(0)
    expect(ui.sidebar_indexes('BAR', schema='FOO')).to_have_text([re.compile(r'my <i> \(Y\)$')])

    ui.index_menu('T_Y').get_by_role('button', name='Drop index').click()
    expect(ui.confirm_sql).to_have_text('DROP INDEX PUBLIC.T_Y')
    ui.confirm.get_by_role('link', name='Cancel').click()
    expect(ui.sidebar_indexes('T')).to_have_count(2)

    ui.index_menu('my <i>', schema='FOO').get_by_role('button', name='Drop index').click()
    expect(ui.confirm_sql).to_have_text('DROP INDEX FOO."my <i>"')
    ui.run_change()
    expect(ui.sidebar_indexes('BAR', schema='FOO')).to_have_count(0)
    assert 'my <i>' not in cli(db_file, 'EXPLAIN SELECT * FROM foo.bar WHERE y;')

    # The table menu is still only the table's.
    expect(ui.table_menu('T').get_by_role('button')).to_have_count(5)


def test_table_menu(ui):
    # INFORMATION_SCHEMA and VSQL_APP don't have a menu.
    for schema in ['INFORMATION_SCHEMA', 'VSQL_APP']:
        expect(ui.schema('db', schema).locator('li')).not_to_have_count(0)
        expect(ui.schema('db', schema).locator('details.menu')).to_have_count(0)
    expect(ui.schema('db', 'FOO').locator('details.menu')).to_have_count(1)

    # Only one menu is open, and a click outside it closes it.
    ui.table_menu('my <t>')
    ui.table_menu('BAR', schema='FOO')
    expect(ui.page.locator('details.menu[open]')).to_have_count(1)
    ui.brand.locator('.version').click()
    expect(ui.page.locator('details.menu[open]')).to_have_count(0)


def test_drop_in_file(page, db_file, make_file, start_app):
    # A table is dropped in the file it's listed under, which the popup shows. The
    # SQL doesn't have the catalog, and a table with the same name in the other
    # file is kept.
    other_file = make_file('other.vsql', 'CREATE TABLE t (x INT);')
    cli(db_file, 'CREATE TABLE t (x INT);')
    ui = AppPage(page, start_app(db_file, other_file))
    ui.table_menu('T', catalog='other').get_by_role('button', name='Drop table').click()
    expect(ui.confirm_sql).to_have_text('DROP TABLE PUBLIC.T')
    expect(ui.confirm.locator('.confirm-file')).to_have_text('other')
    ui.run_change()
    expect(ui.sidebar_table('T', catalog='other')).to_have_count(0)
    expect(ui.sidebar_table('T', catalog='db')).to_have_count(1)


def test_brand_links_to_repo(ui):
    link = ui.brand.get_by_role('link', name='vsql')
    expect(link).to_have_attribute('href', 'https://github.com/elliotchance/vsql')
    expect(link).to_have_attribute('target', '_blank')


def test_system_schemas_start_collapsed(ui):
    for schema in ['INFORMATION_SCHEMA', 'VSQL_APP']:
        expect(ui.folder(f'schema:db.{schema}')).not_to_have_attribute('open', '')
    expect(ui.folder('schema:db.PUBLIC')).to_have_attribute('open', '')

    # Once it's opened it stays open, and collapses again the same way.
    ui.folder('schema:db.VSQL_APP').locator('summary').click()
    expect(ui.folder('schema:db.VSQL_APP')).to_have_attribute('open', '')
    ui.page.wait_for_function("localStorage['vsql.sidebar.expanded']?.includes('VSQL_APP')")
    ui.reload()
    expect(ui.folder('schema:db.VSQL_APP')).to_have_attribute('open', '')
    expect(ui.folder('schema:db.INFORMATION_SCHEMA')).not_to_have_attribute('open', '')
    ui.folder('schema:db.VSQL_APP').locator('summary').click()
    ui.page.wait_for_function("!localStorage['vsql.sidebar.expanded'].includes('VSQL_APP')")
    ui.reload()
    expect(ui.folder('schema:db.VSQL_APP')).not_to_have_attribute('open', '')


def test_tabs_use_the_dot_of_their_file(ui):
    ui.new_catalog_tab('db')
    tab = ui.catalog_tabs('db').first
    expect(tab.locator('.dot')).to_have_count(1)
    expect(tab.locator('.icon')).to_have_count(0)
