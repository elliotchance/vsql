# AppPage is how the tests find things on the page of "vsql app" (and use
# them), so that a change to the HTML only has to be made here. The fixtures
# that set up the files and start the app are in conftest.py.

import re


def titles(*titles):
    """titles matches the text of tabs in the sidebar, after their icon."""
    return [re.compile(re.escape(title) + '$') for title in titles]


class AppPage:
    """AppPage is the page of a running App (see conftest.py)."""

    def __init__(self, page, app):
        self.page = page
        self.open(app)

    def open(self, app):
        """open goes to the page of app, such as after it was started again."""
        self.app = app
        self.page.goto(app.url)

    def reload(self):
        self.page.reload()

    # The sidebar.

    @property
    def sidebar(self):
        return self.page.locator('.sidebar')

    @property
    def brand(self):
        return self.page.locator('.brand')

    @property
    def sections(self):
        """sections are the headings of the sidebar, each catalog then Tabs."""
        return self.page.locator('details.section > summary')

    def folder(self, name):
        """folder is a heading or schema in the sidebar that can be collapsed,
        such as "tabs" or "schema:db.FOO" (see data-folder)."""
        return self.page.locator(f'details[data-folder="{name}"]')

    def schema(self, catalog, schema):
        return self.folder(f'schema:{catalog}.{schema}')

    def sidebar_table(self, name, catalog='db', schema='PUBLIC'):
        """sidebar_table is the button that queries a table in the sidebar."""
        return self.schema(catalog, schema).get_by_role('button', name=name, exact=True)

    @property
    def sidebar_tabs(self):
        """sidebar_tabs are the tabs listed in the sidebar (see titles)."""
        return self.folder('tabs').locator('li')

    def sidebar_tab(self, title):
        return self.folder('tabs').get_by_role('button', name=title, exact=True)

    @property
    def resizer(self):
        return self.page.locator('.resizer')

    def resize_sidebar(self, width):
        """resize_sidebar drags the resizer so the sidebar is width pixels."""
        box = self.resizer.bounding_box()
        y = box['y'] + 100
        self.page.mouse.move(box['x'] + box['width'] / 2, y)
        self.page.mouse.down()
        self.page.mouse.move(width, y, steps=5)
        self.page.mouse.up()

    @property
    def sidebar_width(self):
        return self.sidebar.bounding_box()['width']

    # The tab bar.

    @property
    def tab_bar(self):
        """tab_bar is each tab, its text is the title then the close button."""
        return self.page.locator('.tabs .tab')

    @property
    def active_tab(self):
        return self.page.locator('.tabs .tab.active')

    def tab(self, title):
        """tab is the button that goes to a tab in the tab bar."""
        return self.page.locator('.tabs').get_by_role('button', name=title, exact=True)

    def new_tab(self):
        self.page.get_by_role('button', name='+').click()

    @property
    def new_tab_button(self):
        return self.page.get_by_role('button', name='+')

    def close_tab(self, tab):
        """close_tab closes a tab in tab_bar (a locator, such as active_tab)."""
        tab.get_by_role('button', name='×').click()

    # The editor and the result.

    @property
    def editor(self):
        return self.page.locator('.editor textarea')

    @property
    def highlighted(self):
        """highlighted is the colored copy of the SQL under the editor."""
        return self.page.locator('.editor pre')

    def run(self, sql):
        """run replaces the SQL of the active tab and runs it."""
        self.editor.fill(sql)
        self.page.get_by_role('button', name=re.compile('^Run')).click()

    @property
    def status(self):
        return self.page.locator('.actions .status')

    @property
    def headers(self):
        """headers are the columns of the result, each is its name then type."""
        return self.page.locator('main th')

    @property
    def rows(self):
        return self.page.locator('main tbody tr')

    @property
    def cells(self):
        return self.page.locator('main td')

    @property
    def error(self):
        return self.page.locator('main .error')

    @property
    def empty(self):
        """empty is the message when there are no tabs or no result yet."""
        return self.page.locator('main .empty')
