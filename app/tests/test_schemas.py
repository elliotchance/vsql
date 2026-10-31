# Creating a schema from the menu of a catalog, and dropping a schema from its
# menu.

import re

from playwright.sync_api import expect

from conftest import cli
from pages import AppPage


def test_create_schema(ui, db_file):
    # Create schema shows the CREATE SCHEMA as the name is entered (a name is
    # shown like the table editor). A schema without tables is shown.
    ui.catalog_menu('db').get_by_role('button', name='Create schema').click()
    expect(ui.create_schema).to_be_visible()
    expect(ui.create_schema.get_by_role('button', name='Create schema')).to_be_disabled()
    ui.create_schema.locator('input').fill('order')
    expect(ui.create_schema.locator('pre')).to_have_text('CREATE SCHEMA "ORDER"')
    ui.create_schema.locator('input').fill('"Mixed"')
    expect(ui.create_schema.locator('pre')).to_have_text('CREATE SCHEMA "Mixed"')
    ui.create_schema.locator('input').fill('reports')
    expect(ui.create_schema.locator('pre')).to_have_text('CREATE SCHEMA REPORTS')
    expect(ui.create_schema.locator('pre .kw').first).to_have_text('CREATE')
    ui.create_schema.locator('input').press('Enter')
    expect(ui.create_schema).not_to_be_visible()
    expect(ui.schema('db', 'REPORTS').locator('summary .count')).to_have_text('0')
    expect(ui.schema('db', 'REPORTS').locator('li')).to_have_text(['There are no tables.'])
    cli(db_file, 'CREATE TABLE reports.t (x INT);')

    # Cancel doesn't create it, and an error (such as a schema that already
    # exists) is shown.
    ui.catalog_menu('db').get_by_role('button', name='Create schema').click()
    ui.create_schema.locator('input').fill('other')
    ui.create_schema.get_by_role('button', name='Cancel').click()
    expect(ui.create_schema).not_to_be_visible()
    ui.reload()
    expect(ui.schema('db', 'OTHER')).to_have_count(0)

    ui.catalog_menu('db').get_by_role('button', name='Create schema').click()
    expect(ui.create_schema.locator('input')).to_have_value('')
    ui.create_schema.locator('input').fill('foo')
    ui.create_schema.get_by_role('button', name='Create schema').click()
    expect(ui.error).to_have_text('duplicate schema: FOO')


def test_create_schema_catalogs(page, db_file, make_file, start_app):
    # With more than one catalog, a schema is created in the catalog of the
    # menu.
    other_file = make_file('other.vsql', 'CREATE TABLE t (x INT);')
    ui = AppPage(page, start_app(db_file, other_file))
    ui.catalog_menu('other').get_by_role('button', name='Create schema').click()
    ui.create_schema.locator('input').fill('reports')
    expect(ui.create_schema.locator('pre')).to_have_text('CREATE SCHEMA "other".REPORTS')
    ui.create_schema.get_by_role('button', name='Create schema').click()
    expect(ui.schema('other', 'REPORTS')).to_have_count(1)
    expect(ui.schema('db', 'REPORTS')).to_have_count(0)


def test_drop_schema(ui, db_file):
    # A schema is dropped once it's confirmed. An empty schema is RESTRICT, a
    # schema with tables is dropped with them (CASCADE).
    cli(db_file, 'CREATE SCHEMA unused;')
    ui.reload()
    ui.schema_menu('db', 'UNUSED').get_by_role('button', name='Drop schema').click()
    expect(ui.confirm_sql).to_have_text('DROP SCHEMA UNUSED RESTRICT')
    expect(ui.confirm.get_by_role('button', name='Run')).to_have_class('delete')
    ui.confirm.get_by_role('link', name='Cancel').click()
    expect(ui.schema('db', 'UNUSED')).to_have_count(1)

    ui.schema_menu('db', 'UNUSED').get_by_role('button', name='Drop schema').click()
    ui.run_change()
    expect(ui.schema('db', 'UNUSED')).to_have_count(0)

    ui.schema_menu('db', 'FOO').get_by_role('button', name='Drop schema').click()
    expect(ui.confirm_sql).to_have_text('DROP SCHEMA FOO CASCADE')
    ui.run_change()
    expect(ui.schema('db', 'FOO')).to_have_count(0)
    assert 'BAR' not in cli(db_file, 'SELECT table_name FROM INFORMATION_SCHEMA.TABLES;')
