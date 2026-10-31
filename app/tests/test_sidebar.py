# The sidebar: the version, each catalog with its tables under their schema,
# and the tabs. It can be collapsed and resized, and a table dropped.

import re

from playwright.sync_api import expect

from conftest import cli
from pages import AppPage


def test_sidebar(ui):
    # The sidebar has the version, the catalog with its tables under their
    # schema (including VSQL_APP.TABS) and the tabs.
    expect(ui.brand).to_have_text('vsql v0.0.0')
    expect(ui.sections).to_have_text([re.compile('db$'), re.compile('Tabs 0$')])
    for schema, table in [('FOO', 'FOO.BAR'), ('PUBLIC', 'PUBLIC."my <t>"'), ('VSQL_APP', 'VSQL_APP.TABS')]:
        expect(ui.schema('db', schema).locator('summary .count')).to_have_text('1')
        expect(ui.schema('db', schema).locator('li > button')).to_have_attribute('value', table)
    expect(ui.sidebar_table('my <t>')).to_have_attribute('title', 'SELECT * FROM PUBLIC."my <t>"')


def test_sidebar_is_remembered(ui):
    # A heading or schema can be collapsed, and the sidebar resized (a
    # double-click goes back to the default width), which the browser
    # remembers.
    ui.schema('db', 'FOO').locator('summary').click()
    expect(ui.schema('db', 'FOO')).not_to_have_attribute('open', '')
    ui.folder('tabs').locator('> summary').click()

    default_width = ui.sidebar_width
    ui.resize_sidebar(400)
    width = ui.sidebar_width
    assert abs(width - 400) < 10

    ui.reload()
    expect(ui.schema('db', 'FOO')).not_to_have_attribute('open', '')
    expect(ui.folder('tabs')).not_to_have_attribute('open', '')
    expect(ui.schema('db', 'PUBLIC')).to_have_attribute('open', '')
    assert ui.sidebar_width == width

    ui.resizer.dblclick()
    ui.reload()
    assert ui.sidebar_width == default_width


def test_catalogs(page, db_file, make_file, start_app):
    # Other files are attached as catalogs, each with its own heading. With
    # more than one catalog, a table is queried with its catalog.
    other_file = make_file('other.vsql', 'CREATE TABLE t (x INT);')
    ui = AppPage(page, start_app(db_file, other_file))
    expect(ui.sections).to_have_text([re.compile('db$'), re.compile('other$'), re.compile('Tabs 0$')])
    expect(ui.sidebar_table('T', catalog='other')).to_have_attribute('value', '"other".PUBLIC.T')
    expect(ui.sidebar_table('BAR', schema='FOO')).to_have_attribute('value', '"db".FOO.BAR')
    ui.sidebar_table('T', catalog='other').click()
    expect(ui.editor).to_have_value('SELECT * FROM "other".PUBLIC.T')
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


def test_table_menu(ui):
    # INFORMATION_SCHEMA and VSQL_APP don't have a menu.
    for schema in ['INFORMATION_SCHEMA', 'VSQL_APP']:
        expect(ui.schema('db', schema).locator('li')).not_to_have_count(0)
        expect(ui.schema('db', schema).locator('details.menu')).to_have_count(0)
    expect(ui.schema('db', 'FOO').locator('details.menu')).to_have_count(1)

    # Only one menu is open, and a click outside it closes it.
    ui.table_menu('BAR', schema='FOO')
    ui.table_menu('my <t>')
    expect(ui.page.locator('details.menu[open]')).to_have_count(1)
    ui.brand.click()
    expect(ui.page.locator('details.menu[open]')).to_have_count(0)
