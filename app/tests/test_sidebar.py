# The sidebar: the version, each catalog with its tables under their schema,
# and the tabs. It can be collapsed and resized.

import re

from playwright.sync_api import expect

from pages import AppPage


def test_sidebar(ui):
    # The sidebar has the version, the catalog with its tables under their
    # schema (including VSQL_APP.TABS) and the tabs.
    expect(ui.brand).to_have_text('vsql v0.0.0')
    expect(ui.sections).to_have_text([re.compile('db$'), re.compile('Tabs 0$')])
    for schema, table in [('FOO', 'FOO.BAR'), ('PUBLIC', 'PUBLIC."my <t>"'), ('VSQL_APP', 'VSQL_APP.TABS')]:
        expect(ui.schema('db', schema).locator('summary .count')).to_have_text('1')
        expect(ui.schema('db', schema).locator('button')).to_have_attribute('value', table)
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
