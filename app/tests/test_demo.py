# Load demo data in the menu of a file opens a tab to choose what to load. The
# browser downloads it, then it creates a schema and imports it like any other file.
# The tests don't use the network, the download is answered by serve_chinook.

from playwright.sync_api import expect

from conftest import cli, count

CHINOOK_URL = '**/lerocha/chinook-database/**/Chinook_Sqlite.sql'
COUNTRIES_URL = '**/lukes/ISO-3166-Countries-with-Regional-Codes/**/all.csv'

COUNTRIES_CSV = """name,alpha-2,alpha-3,country-code,iso_3166-2,region,sub-region,intermediate-region,region-code,sub-region-code,intermediate-region-code
Afghanistan,AF,AFG,004,ISO 3166-2:AF,Asia,Southern Asia,"",142,034,""
"Korea, Republic of",KR,KOR,410,ISO 3166-2:KR,Asia,Eastern Asia,"",142,030,""
"""

# What the file looks like: SQLite syntax, and it has indexes.
CHINOOK_SQL = """DROP TABLE IF EXISTS [Artist];
CREATE TABLE [Artist]
(
    [ArtistId] INTEGER NOT NULL,
    [Name] NVARCHAR(120),
    CONSTRAINT [PK_Artist] PRIMARY KEY ([ArtistId])
);
CREATE INDEX [IFK_Artist] ON [Artist] ([Name]);
INSERT INTO [Artist] ([ArtistId], [Name]) VALUES (1, 'AC/DC');
INSERT INTO [Artist] ([ArtistId], [Name]) VALUES (2, 'Accept');
"""


def serve_chinook(ui):
    ui.page.route(CHINOOK_URL, lambda route: route.fulfill(
        body=CHINOOK_SQL, headers={'Access-Control-Allow-Origin': '*'}))


def open_demo(ui):
    ui.catalog_menu('db').get_by_role('button', name='Load demo data…').click()
    expect(ui.active_tab).to_contain_text('Demo data')


def schema_input(ui):
    return ui.page.locator('[name="demo_schema"]')


def load_button(ui):
    return ui.page.get_by_role('button', name='Load', exact=True)


def test_open_demo(ui):
    open_demo(ui)
    expect(ui.page.locator('[name="demo"] option')).to_have_text(['Chinook', 'Countries'])
    expect(ui.page.locator('[name="demo"]')).to_have_value('chinook')
    expect(ui.page.locator('.demo-description:visible')).to_contain_text('11 tables')
    expect(ui.page.get_by_role('link', name='github.com/lerocha/chinook-database')).to_have_attribute(
        'href', 'https://github.com/lerocha/chinook-database')
    expect(schema_input(ui)).to_have_value('chinook')
    # Nothing is created until it's loaded.
    expect(ui.schema('db', 'CHINOOK')).to_have_count(0)


def test_schema_is_required(ui):
    open_demo(ui)
    expect(load_button(ui)).to_be_enabled()
    schema_input(ui).fill('  ')
    expect(load_button(ui)).to_be_disabled()
    # A name that needs quotes could be read differently by the dialect of the file.
    for name in ['"My Music"', 'My Music', '1a', "a'b"]:
        schema_input(ui).fill(name)
        expect(load_button(ui)).to_be_disabled()
    schema_input(ui).fill('music_2')
    expect(load_button(ui)).to_be_enabled()


def test_schema_is_kept_on_the_tab(ui):
    open_demo(ui)
    schema_input(ui).fill('music')
    ui.new_tab()
    ui.tab('Demo data').click()
    expect(schema_input(ui)).to_have_value('music')


def test_load_demo(ui, db_file):
    serve_chinook(ui)
    open_demo(ui)
    schema_input(ui).fill('music')
    load_button(ui).click()

    expect(ui.page.locator('main .notice')).to_contain_text('chinook.sql', timeout=30000)
    expect(ui.sidebar_table('ARTIST', schema='MUSIC')).to_be_visible()
    assert count(db_file, 'SELECT COUNT(*) FROM music.artist;') == 2
    # The index is created.
    assert 'DROP INDEX 1' in cli(db_file, 'DROP INDEX music.ifk_artist;')


def test_download_fails(ui):
    ui.page.route(CHINOOK_URL, lambda route: route.abort())
    open_demo(ui)
    load_button(ui).click()
    expect(ui.page.locator('.demo-message')).to_contain_text('could not be downloaded')
    # Nothing was changed, and it can be tried again.
    expect(ui.schema('db', 'CHINOOK')).to_have_count(0)
    expect(load_button(ui)).to_be_enabled()
    expect(load_button(ui)).to_have_text('Load')


def test_download_not_found(ui):
    ui.page.route(CHINOOK_URL, lambda route: route.fulfill(
        status=404, body='404: Not Found', headers={'Access-Control-Allow-Origin': '*'}))
    open_demo(ui)
    load_button(ui).click()
    expect(ui.page.locator('.demo-message')).to_contain_text('could not be downloaded')
    expect(ui.schema('db', 'CHINOOK')).to_have_count(0)


def test_load_into_existing_schema(ui, db_file):
    # The table with another name is kept, and the file replaces the one with its name.
    cli(db_file, 'CREATE SCHEMA chinook; CREATE TABLE chinook.mine (x INT); INSERT INTO chinook.mine (x) VALUES (1); CREATE TABLE chinook.artist (x INT);')
    serve_chinook(ui)
    open_demo(ui)
    load_button(ui).click()
    expect(ui.page.locator('main .notice')).to_contain_text('chinook.sql', timeout=30000)
    assert count(db_file, 'SELECT COUNT(*) FROM chinook.artist;') == 2
    assert count(db_file, 'SELECT COUNT(*) FROM chinook.mine;') == 1


def test_schema_of_the_app_is_refused(ui, db_file):
    serve_chinook(ui)
    open_demo(ui)
    schema_input(ui).fill('vsql_app')
    load_button(ui).click()
    expect(ui.error).to_contain_text('cannot be loaded into VSQL_APP')
    expect(schema_input(ui)).to_have_value('vsql_app')
    assert count(db_file, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ARTIST';") == 0


def choose_countries(ui):
    ui.page.route(COUNTRIES_URL, lambda route: route.fulfill(
        body=COUNTRIES_CSV, headers={'Access-Control-Allow-Origin': '*'}))
    open_demo(ui)
    ui.page.locator('[name="demo"]').select_option('countries')


def test_choose_countries(ui):
    choose_countries(ui)
    expect(schema_input(ui)).to_have_value('countries')
    expect(ui.page.locator('.demo-description:visible')).to_contain_text('249 countries')
    expect(ui.page.locator('.demo-description:visible')).to_contain_text('about 21 KB')


def test_load_countries(ui, db_file):
    choose_countries(ui)
    load_button(ui).click()
    expect(ui.page.locator('main .notice')).to_contain_text('countries.csv', timeout=30000)
    assert count(db_file, 'SELECT COUNT(*) FROM countries.countries;') == 2
    # A comma in a quoted name, and only the mapped fields are imported.
    assert count(db_file, "SELECT COUNT(*) FROM countries.countries WHERE name = 'Korea, Republic of' AND code3 = 'KOR' AND sub_region = 'Eastern Asia';") == 1


def test_countries_table_already_exists(ui, db_file):
    cli(db_file, 'CREATE SCHEMA countries; CREATE TABLE countries.countries (x INT); INSERT INTO countries.countries (x) VALUES (1);')
    choose_countries(ui)
    load_button(ui).click()
    expect(ui.error).to_contain_text('rolled back', timeout=30000)
    assert count(db_file, 'SELECT COUNT(*) FROM countries.countries;') == 1
