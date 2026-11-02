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
        """sections are the headings of the sidebar, each catalog."""
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
        return self.page.locator('details[data-folder^="tabs:"] li > button')

    @property
    def sidebar_tab_rows(self):
        """sidebar_tab_rows are the items of the tabs in the sidebar, the
        active one has the class active."""
        return self.page.locator('details[data-folder^="tabs:"] li')

    def sidebar_tab(self, title):
        return self.page.locator('details[data-folder^="tabs:"]').get_by_role('button', name=title, exact=True)

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
    def tab_catalog(self):
        """tab_catalog is the name of the file that the active tab runs in."""
        return self.page.locator('.actions .catalog')

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

    def tab_menu(self, title):
        """tab_menu opens the menu of a tab in the sidebar, and returns it."""
        li = self.page.locator('details[data-folder^="tabs:"] li').filter(has=self.page.get_by_role('button', name=title, exact=True))
        li.hover()
        li.locator('details.menu > summary').click()
        return li.locator('.menu-items')

    # The values of each "?" (see test_params.py).

    def param(self, number):
        """param is the input for a "?", from 1."""
        return self.page.locator(f'.params input[name="param:{number}"]')

    def param_type(self, number):
        """param_type is the select of the type of a "?", from 1."""
        return self.page.locator(f'.params select[name="param_type:{number}"]')

    @property
    def params(self):
        return self.page.locator('.params input')

    # The history (see test_history.py).

    @property
    def history_nav(self):
        """history_nav is the button in the sidebar for the history of the only
        file."""
        return self.page.locator('button.history-nav')

    def catalog_history_nav(self, catalog):
        """catalog_history_nav is the button in the sidebar for the history of a
        file."""
        return self.page.get_by_role('button', name=f'Query History of {catalog}', exact=True)

    @property
    def history_search(self):
        return self.page.locator('input.history-search')

    def catalog_tabs(self, catalog):
        """catalog_tabs are the tabs of a file in the sidebar."""
        return self.folder(f'tabs:{catalog}').locator('li > button')

    def new_catalog_tab(self, catalog):
        """new_catalog_tab adds a tab to a file from the sidebar."""
        self.page.get_by_role('button', name=f'New tab in {catalog}', exact=True).click()

    @property
    def history_button(self):
        return self.page.locator('button.show-history')

    @property
    def history(self):
        """history is the popup of the queries run in the tab."""
        return self.page.locator('dialog.history')

    @property
    def history_entries(self):
        """history_entries are the queries shown in the popup, the latest
        first."""
        return self.history.locator('li:not([hidden]) button')

    # Changing the rows of an editable result (see test_edit.py).

    @property
    def editable(self):
        """editable is the result when its rows can be changed."""
        return self.page.locator('main table.editable')

    def cell(self, row, column):
        """cell is the cell of a column (by name) that can be edited, in the
        row (from 0) of the result."""
        return self.rows.nth(row).locator(f'td[data-column="{column}"]')

    @property
    def edit_button(self):
        """edit_button is Edit..., which becomes Cancel edit and then Save X
        changes."""
        return self.page.locator('button.edit')

    @property
    def cancel_edit(self):
        """cancel_edit throws away the changes, when there are any."""
        return self.page.locator('button.cancel-edit')

    @property
    def edit_hint(self):
        """edit_hint says what the special values are while editing."""
        return self.page.locator('.edit-hint')

    def control(self, row, column):
        """control is the input (or select) of a cell that's being edited."""
        return self.cell(row, column).locator('.cell-control')

    def edit(self, row, column, value):
        """edit clicks a cell, enters the value and presses Enter."""
        self.cell(row, column).click()
        self.control(row, column).fill(value)
        self.control(row, column).press('Enter')

    def row_button(self, row):
        """row_button is the button at the start of a row: delete, undo or
        remove."""
        return self.rows.nth(row).locator('td.row-actions button')

    def delete_row(self, row):
        self.row_button(row).click()

    def add_row(self):
        self.page.locator('main tfoot').get_by_role('button', name='+').click()

    @property
    def tab_id(self):
        """tab_id is the reference of the active tab (its catalog and id), to post
        a change directly."""
        return self.page.locator('input[name="tab"]').first.get_attribute('value')
