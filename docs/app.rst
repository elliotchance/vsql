Browser App
===========

``vsql app`` browses, queries and changes database files in a web browser. Start
it with one or more files, then open the address that it prints:

.. code-block:: text

   $ vsql app shop.vsql
   ready on http://127.0.0.1:3211

See :ref:`cli:app` for its options, such as the port. The colors follow the light
or dark setting of the system.

Files
-----

Each file is a catalog, named after its file up to the first ``.`` (so
``shop.vsql`` is ``shop``). The first file is the current catalog, and the
others are attached to it. Each file has its own colored dot, which is next to
its name in the sidebar and in front of each of its tabs.

Every tab belongs to a file: its SQL runs in that file, and its tabs and history
are saved in that file (see `What the App Keeps in a File`_). The tabs are there
again the next time the file is opened.

Sidebar
-------

The sidebar has a heading for each file, with its tabs and then its schemas.
Each schema has its tables (and then its sequences), and each table has its
columns, then its indexes and constraints. Clicking a schema or table opens or
closes it, and the browser remembers which ones are closed. The sidebar can be
made wider or narrower by dragging its edge, and double-clicking the edge puts it
back to its default width.

A column has a colored square for its type: blue for numbers, green for
strings, orange for dates and times and purple for ``BOOLEAN``. The name of a
``NOT NULL`` column is underlined, and a column in the ``PRIMARY KEY`` has a
key.

The menu of a file can:

- **Create schema**: Enter the name of a new schema, which shows the
  ``CREATE SCHEMA`` that's run.
- **Import**: Import a file (see `Importing`_).
- **Load demo data**: See `Demo Data`_.
- **Export**: Export the file (see `Exporting`_).
- **Query History**: See `Query History`_.

The menu of a schema can **Add table** (see `Creating and Altering Tables`_),
**Import** into the schema, **Export** the schema, or **Drop schema**. The menu
of a table can:

- **Select**: Open a new tab that runs ``SELECT *`` on the table.
- **Alter table**: See `Creating and Altering Tables`_.
- **Create index**: Choose the columns of the index (in order), each ``ASC`` or
  ``DESC``, and its name, which shows the ``CREATE INDEX`` that's run. The name
  is made from the names of the table and columns until it's changed.
- **Import** into the table, or **Export** it.
- **Drop table**.

An index or a constraint has a menu to drop it. A ``PRIMARY KEY`` or ``UNIQUE``
constraint that a ``FOREIGN KEY`` references is dropped with ``CASCADE``, which
drops the ``FOREIGN KEY`` too. Each drop shows the statement to confirm it
before it's run. ``INFORMATION_SCHEMA`` and ``VSQL_APP`` (see
`What the App Keeps in a File`_) don't have these menus, and start closed.

Queries
-------

The ``+`` in the tab bar (or next to the tabs of a file in the sidebar) adds a
tab, which starts with ``SELECT * FROM INFORMATION_SCHEMA.TABLES``. **Run** (or
Ctrl+Enter, or Cmd+Enter on a Mac) runs every statement in the editor, and shows
the result of the last one with the number of rows (or the message of the
statement) and how long they took. An error stops at the statement that failed.
Going back to a tab shows its last result, it doesn't run it again.

Under the result's column names are their types. Clicking a column sorts the
rows by it, clicking it again sorts the other way, and a third time goes back to
the order of the query. The query itself is sorted, by adding an ``ORDER BY``
and running it again (a query that has its own ``ORDER BY``, ``FETCH``,
``OFFSET`` or ``LIMIT`` is sorted as a subquery). A column without a name, such
as ``COL1``, can't be sorted.

A string that's longer than 50 characters is cut short, with a button to see all
of it and copy it. At most 10,000 rows are shown, change the query (such as with
``FETCH FIRST``) to see others.

The schema next to the file is the schema that the tab runs in (``PUBLIC`` by
default), so a name doesn't need its schema. Each tab remembers its own schema.

**Explain** runs the statement with ``EXPLAIN`` in front of it and shows the
plan (see :doc:`explain`), without changing the SQL of the tab.

Parameters
^^^^^^^^^^

Each ``?`` in the SQL (that isn't in a string, a quoted name or a comment) has
an input under the editor for its value, and a type. The type is guessed from
the value (``Text``, ``Number``, ``Boolean``, ``Date``, ``Time`` or
``Timestamp``) until another one is chosen. ``TRUE``, ``FALSE``, ``UNKNOWN`` and
``NULL`` don't need a value. The values are saved with the tab.

Editing Rows
------------

The rows of a result can be changed when the query is ``SELECT *`` from a single
table that has a ``PRIMARY KEY`` (optionally with ``WHERE``, ``ORDER BY``,
``OFFSET`` or ``FETCH``). Otherwise the **Edit** button is disabled, since there
would be no way to say which row to change.

**Edit** makes the cells editable. Clicking a cell changes it: Enter keeps the
value, Escape puts it back and Tab goes to the next cell. In a cell, an empty
value is the column's ``DEFAULT``, ``\N`` is ``NULL`` and ``""`` is an empty
string. A generated column, or an identity column that's ``GENERATED ALWAYS``,
can't be changed.

The changes are collected until they're saved: a changed row is yellow (with a
button to undo it), a row to be deleted is red, and a new row (added with ``+``
at the end) is green. **Save** runs every change in one transaction, and each
must change exactly one row. If any of them fails nothing is changed, and the
changes are kept to try again. **Cancel edit** throws them away.

Creating and Altering Tables
----------------------------

**Add table** in the menu of a schema opens a tab with the schema, the name of
the table and its columns, which starts with an auto increment ``ID`` column as
the ``PRIMARY KEY``. Each column has a name, a type, ``NOT NULL``,
``PRIMARY KEY``, auto increment and ``DEFAULT``. The ``CREATE TABLE`` is shown
as it's built. **Create table** runs it, closes the tab and opens the new table
in a query tab.

**Alter table** in the menu of a table opens a similar tab for the table. Any
column can be added, but a column that's already there can only have its
``NOT NULL`` removed, its ``DEFAULT`` changed, be added to or removed from the
``PRIMARY KEY``, or be removed. The ``ALTER TABLE`` statements are shown as
they're built. **Alter table** runs them in one transaction (so nothing is
changed if one fails), closes the tab and opens the table in a query tab.

Importing
---------

**Import** (in the menu of a file, schema or table) opens a tab to import a
``.sql``, ``.csv``, ``.tsv`` or ``.json`` file. It's the same as
:ref:`cli:in`, and the tab shows the ``vsql in`` command with a button to copy
it.

Choosing a file shows roughly how many rows (or statements) and fields it has,
and the options for its type:

- A SQL file has the schema that statements without a schema run in, which
  dialect it's in (``vsql`` or ``sqlite3``), whether to ignore
  ``CREATE VIEW``, ``CREATE TRIGGER`` and ``CREATE INDEX``, and whether to run
  it in one transaction.
- A CSV, TSV or JSON file goes into an existing table or a new table. Each field
  of the file goes into a column (the one with the same name to start with), or
  is skipped. For a new table, the columns and their types are guessed from the
  first rows of the file, and can be changed.

**On failure** either stops at the first failure or continues. **Import** shows
the progress while the file is imported in the background, which can be
cancelled. Afterwards the tab shows what was done (such as the rows inserted),
any errors and warnings with the line of the file, and a button to view the
table. The import runs at the isolation level of ``-isolation`` (see
:ref:`cli:app`), so the app can still be used while a big file is imported.

Demo Data
^^^^^^^^^

**Load demo data** in the menu of a file opens a tab to choose something to load
into a schema of its own (``chinook`` or ``countries``, which can be changed):

- **Chinook**: A digital media store with 11 tables and about 15,000 rows
  (about 600 KB to download).
- **Countries**: A ``COUNTRIES`` table with the 249 countries and territories of
  ISO 3166 (about 21 KB to download).

The browser downloads the file from its project on GitHub, then it's imported
like any other file. The tab describes each one and links to where it's from.

Exporting
---------

**Export** opens a tab to export a file, schema or table, or the last statement
of a query tab (with the **Export** button next to the result). It's the same as
:ref:`cli:out`, and the tab shows the ``vsql out`` command with a button to copy
it. **Export** downloads the file.

A file, schema or table can be exported as SQL, which has a checkbox for each
schema and object to choose what to export, and the options of ``vsql out``
(such as which database it's for, and whether it's the schema, the data or
both). A table or query can also be exported as CSV, TSV or JSON. ``VSQL_APP``
isn't selected when a whole file is exported.

Query History
-------------

Each query that's run is saved in the history of its tab, with when it ran and
the number of rows, its message or its error. **Query History** next to the
result shows the history of the tab: choosing a query puts it in the editor
without running it.

**Query History** in the menu of a file opens a tab with the history of every tab
of the file, the latest first. Choosing a query opens it in a new tab without
running it. Both can be searched, in the SQL and its outcome.

The last 100 queries of each tab are kept, and the history of a tab is removed
when the tab is closed.

What the App Keeps in a File
----------------------------

The app keeps its tabs (with their SQL, parameters and options) in
``VSQL_APP.TABS``, and the history in ``VSQL_APP.HISTORY``, in each file. It
creates them when it opens a file. Use ``-exclude 'VSQL_APP.*'`` with
``vsql out`` to leave them out of an export (see :ref:`cli:out`).

The last result of each tab isn't kept, so it's empty when the app is started
again until the tab is run.
