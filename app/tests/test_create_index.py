# Creating an index from the menu of a table.

from playwright.sync_api import expect

from conftest import cli
from pages import AppPage


def has_index(db_file, name):
    """has_index is true if the index exists, which is checked by dropping it
    in a transaction that's rolled back."""
    output = cli(db_file, f'START TRANSACTION; DROP INDEX {name}; ROLLBACK;')
    return 'DROP INDEX 1' in output


def test_create_index(page, db_file, start_app):
    # The columns are in the index in the order they're chosen, each ASC or
    # DESC. The name is made from the table and the columns, until it's
    # changed (other characters are replaced with _). The CREATE INDEX is shown as it's chosen.
    cli(db_file, 'CREATE TABLE t (a INT, "b c" INT, "order" INT);')
    ui = AppPage(page, start_app(db_file))
    ui.table_menu('T').get_by_role('button', name='Create index').click()
    dialog = ui.create_index
    expect(dialog).to_be_visible()
    expect(dialog.locator('.confirm-file')).to_have_text('db')
    expect(dialog.locator('.index-columns .name')).to_have_text(['A', 'b c', 'order'])
    expect(dialog.get_by_role('button', name='Create index')).to_be_disabled()
    expect(ui.index_column('A').locator('select')).to_be_disabled()

    ui.index_column('order').locator('input').check()
    ui.index_column('A').locator('input').check()
    expect(dialog.locator('.index-columns .position')).to_have_text(['2', '', '1'])
    expect(dialog.locator('.index-name input')).to_have_value('T_order_A')
    expect(dialog.locator('pre')).to_have_text('CREATE INDEX T_ORDER_A ON PUBLIC.T ("order", A)')
    expect(dialog.locator('pre .kw').first).to_have_text('CREATE')

    ui.index_column('order').locator('select').select_option('DESC')
    ui.index_column('b c').locator('input').check()
    ui.index_column('A').locator('input').uncheck()
    expect(dialog.locator('.index-columns .position')).to_have_text(['', '2', '1'])
    expect(dialog.locator('pre')).to_have_text('CREATE INDEX T_ORDER_B_C ON PUBLIC.T ("order" DESC, "b c")')

    dialog.locator('.index-name input').fill('t_idx')
    ui.index_column('A').locator('input').check()
    expect(dialog.locator('.index-name input')).to_have_value('t_idx')
    expect(dialog.locator('pre')).to_have_text('CREATE INDEX T_IDX ON PUBLIC.T ("order" DESC, "b c", A)')
    dialog.get_by_role('button', name='Create index').click()
    expect(dialog).not_to_be_visible()
    expect(ui.error).to_have_count(0)
    assert has_index(db_file, 't_idx')

    # Each time it's opened it starts again. Cancel doesn't create it, and an
    # error (such as an index that already exists) is shown.
    ui.table_menu('T').get_by_role('button', name='Create index').click()
    expect(dialog.locator('.index-name input')).to_have_value('')
    expect(dialog.locator('.index-columns input:checked')).to_have_count(0)
    ui.index_column('A').locator('input').check()
    dialog.get_by_role('button', name='Cancel').click()
    expect(dialog).not_to_be_visible()
    assert not has_index(db_file, 't_a')

    ui.table_menu('T').get_by_role('button', name='Create index').click()
    ui.index_column('A').locator('input').check()
    dialog.locator('.index-name input').fill('t_idx')
    dialog.get_by_role('button', name='Create index').click()
    expect(ui.error).to_contain_text('T_IDX')


def test_create_index_catalogs(page, db_file, make_file, start_app):
    # With more than one catalog, the index is created in the catalog of the
    # table, and a table in another schema is qualified.
    other_file = make_file('other.vsql', 'CREATE TABLE t (x INT);')
    cli(db_file, 'CREATE TABLE t (x INT);')
    ui = AppPage(page, start_app(db_file, other_file))
    ui.table_menu('T', catalog='other').get_by_role('button', name='Create index').click()
    expect(ui.create_index.locator('.confirm-file')).to_have_text('other')
    ui.index_column('X').locator('input').check()
    ui.create_index.get_by_role('button', name='Create index').click()
    expect(ui.create_index).not_to_be_visible()
    assert has_index(other_file, 't_x')
    assert not has_index(db_file, 't_x')

    ui.table_menu('BAR', catalog='db', schema='FOO').get_by_role('button', name='Create index').click()
    ui.index_column('Y').locator('input').check()
    expect(ui.create_index.locator('pre')).to_have_text('CREATE INDEX BAR_Y ON FOO.BAR (Y)')
