Command Line Interface (CLI)
============================

.. contents::

Installing
----------

Download a binary from the
`Releases <https://github.com/elliotchance/vsql/releases>`_ page (under Assets).
These binaries do not require V to be installed. See :doc:`install` for other
options.

Commands
--------

Run ``vsql help`` to list the commands, or ``vsql <command> -help`` to see the
options for a command.

app
^^^

``app`` starts a web server to browse and query database files in a browser.
Open the address it prints in a browser.

With no file, ``app.vsql`` in the current directory is used (it's created if it
doesn't exist). More than one file can be given, the other files are attached
as catalogs. An in-memory database (``:memory:``) can't be used, since each
request opens the files again.

.. code-block:: text

   $ vsql app mydb.vsql
   ready on http://127.0.0.1:3211

   $ vsql app    # uses app.vsql
   ready on http://127.0.0.1:3211

Options are:

- ``-host``: Address to listen on (default 127.0.0.1). Use ``0.0.0.0`` or
  ``::`` to accept connections from other machines.
- ``-port`` or ``-p``: Port number (default 3211).

bench
^^^^^

``bench`` runs a benchmark (see :doc:`benchmark`):

.. code-block:: sh

   vsql bench                                 # on disk, in bench.vsql
   vsql bench -file ':memory:'                # in memory
   vsql bench -accounts 1000 -duration 5      # a quick test

Options are:

- ``-file`` or ``-f``: The database file, which is deleted and created for the
  test (default ``bench.vsql``). Use ``:memory:`` for an in-memory database.
- ``-accounts``: The number of rows in the ``ACCOUNTS`` table (default 100000).
- ``-duration``: The number of seconds to run transactions for (default 60).

cli
^^^

``cli`` provides a command prompt for running SQL statements. The file is
created if it doesn't exist. Results are shown as a table, with numbers
right-aligned. Type ``exit`` (or press ctrl+c) to leave:

.. code-block:: text

   $ vsql cli test.vsql
   vsql> CREATE TABLE foo (a INT);
   CREATE TABLE 1 (0 ms)

   vsql> INSERT INTO foo (a) VALUES (1234);
   INSERT 1 (1 ms)

   vsql> SELECT * FROM foo;
      A
   ----
   1234
   1 row (0 ms)

   vsql> exit

Use ``:memory:`` as the file name for an in-memory database.

The shell is direct invocation of SQL (ISO/IEC 9075-2:2016(E), Clause 22,
"Direct invocation of SQL"):

- Each statement ends with a semicolon, so it can be over many lines (``->``
  is shown until the statement is finished). A statement without a semicolon at
  the end of the input is a syntax error.
- A statement can't contain a parameter (``?`` or ``:name``), since there's
  nothing to provide its value.
- By default, a statement that isn't inside a :doc:`start-transaction` is
  committed when it finishes (autocommit). The SQL standard doesn't have
  autocommit, so use ``-autocommit=false`` to follow it: any statement other
  than ``SET CATALOG``, ``SET SCHEMA`` and ``SET CONSTRAINTS`` then starts a
  transaction (if there isn't one), which stays active until a :doc:`commit`
  or :doc:`rollback`. ``START TRANSACTION`` must be the first statement of a
  transaction, otherwise it's ``25001``, and other connections don't see the
  changes until it's committed. At the end of the input (or ``exit``), an active
  transaction is committed.
- A transaction that is still active when the shell stops any other way (such
  as with ctrl+c), or a ``START TRANSACTION`` that isn't finished with
  autocommit, is rolled back.
- The file is the default connection. :doc:`connect` opens other files as
  other connections, and :doc:`set-connection` and :doc:`disconnect` select
  and close them. Only one connection can have an active transaction.
- A query with no rows raises ``02000`` (no data), which is shown as a notice.
- The null value is shown as ``NULL``.

.. code-block:: text

   $ vsql cli -autocommit=false test.vsql
   vsql> INSERT INTO foo (a)
      ->   VALUES (5678);
   INSERT 1 (1 ms)

   vsql> COMMIT;
   COMMIT (0 ms)

Any other files after the first one are attached as more catalogs (see
:doc:`set-catalog`). Each catalog is named after its file, up to the first
``.``:

.. code-block:: text

   $ vsql cli main.vsql archive.vsql
   vsql> SELECT * FROM archive.public.orders;

in
^^

``in`` is used to load a SQL, CSV, TSV or JSON file into a database:

.. code-block:: text

   $ vsql in mydatabase.vsql < myfile.sql

Only problems are printed. ``-verbose`` also prints a line for each statement
that's run:

.. code-block:: text

   $ vsql in -file myfile.sql -single-transaction -verbose mydatabase.vsql
   0 0/1589 START TRANSACTION
   2 45/1589 CREATE TABLE 1
   9 212/1589 WARNING 01003 null value eliminated in set function
   9 212/1589 SELECT 3
   14 260/1589 ERROR 23505 violates unique constraint: PRIMARY KEY on "mydatabase".PUBLIC.T
   0 260/1589 ROLLBACK

Every line has the line of the file that it's for (0 if it isn't in the file), the
bytes read of the file including that statement, and the size of the file (``?``
for stdin). Then it's the result of the statement, where a statement that returns
rows has the number of rows, or ``ERROR``, ``WARNING`` or ``NOTICE`` with a SQLSTATE
and the message. The SQLSTATE is ``HY000`` for a problem that doesn't have its own,
such as a row that can't be read. So ``awk '$3 == "ERROR"'`` is only the errors.

Everything goes to stdout. A ``NOTICE`` needs ``-verbose``. A ``ROLLBACK`` is always
printed. The exit code is non-zero if anything failed.

The file is read as it's imported, so a problem is only found when it gets there.

You can generate a valid SQL file from an existing database with ``vsql out``.

Options are:

- ``-file``: Read from this file instead of stdin.

- ``-format``: ``sql``, ``csv``, ``tsv`` or ``json``. The default is the
  extension of ``-file``, otherwise ``sql``.

- ``-schema``: The current schema for a SQL file, or the schema of ``-table``.
  The default is ``PUBLIC``.

- ``-table``: The table to import a CSV, TSV or JSON file into. A name is in
  upper case unless it's in double quotes.

- ``-create-table``: Create ``-table`` with these definitions of its columns, such
  as ``"ID INTEGER, NAME VARCHAR(100)"``.

- ``-map``: ``field=column`` puts a field of the file into a column, and can be
  used more than once. Fields that aren't mapped aren't imported. The default is
  that each field goes to the column with its name.

- ``-single-transaction``: Run a SQL file in one transaction. If it stops at an
  error, it's rolled back so nothing is changed. It's an error if the file has its
  own ``START TRANSACTION``, ``COMMIT`` or ``ROLLBACK``.

- ``-compat``: The dialect of a SQL file. It's ``vsql`` by default, or ``sqlite3``
  (see below).

- ``-ignore-unsupported``: Show a warning for ``CREATE VIEW``, ``CREATE TRIGGER``
  and ``CREATE INDEX`` if they can't be run, instead of an error. The import can
  then finish without them, so anything that relies on them (such as a ``UNIQUE``
  index) isn't there.

- ``-verbose``: Print each statement as above.

- ``-continue-on-error``: Show errors, but continue to process the input. A
  non-zero exit code will be returned if any of the statements failed.

A CSV, TSV or JSON file is always in one transaction, with ``INSERT``\ s of up to
200 rows. If one fails, its rows are run one at a time to find those that are
wrong. A row that can't be read (such as a quote that's never closed) always stops
the import and rolls it back, even with ``-continue-on-error``.

For example:

.. code-block:: text

   $ vsql in -file people.csv -schema STAFF -table PEOPLE -create-table "ID INTEGER, NAME VARCHAR(100)" -verbose mydatabase.vsql
   0 0/9120 START TRANSACTION
   0 0/9120 CREATE TABLE 1
   2 4100/9120 INSERT 200
   202 8200/9120 INSERT 200
   402 9120/9120 INSERT 45
   0 9120/9120 COMMIT

   $ vsql in -file people.csv -table PEOPLE -map surname=LAST_NAME -map id=ID mydatabase.vsql

Loading a SQLite file
~~~~~~~~~~~~~~~~~~~~~

``-compat sqlite3`` loads SQL that's written for SQLite, such as the output of
its ``.dump`` command:

.. code-block:: text

   $ vsql in -file Chinook_Sqlite.sql -compat sqlite3 -ignore-unsupported -single-transaction mydatabase.vsql

This is what's different:

- A name is in upper case, whether it's written as ``[Album]``, ``"Album"``, in
  backticks or as ``Album``, because names aren't case sensitive in SQLite. So all
  of these are the table ``ALBUM``.

- ``NVARCHAR`` is ``VARCHAR``, ``NCHAR`` is ``CHARACTER``, and ``DATETIME`` is
  ``TIMESTAMP(0) WITHOUT TIME ZONE``. Strings are converted for a ``DATETIME``
  column in the ``VALUES`` of an ``INSERT``.

- ``DROP TABLE IF EXISTS`` is fine if the table doesn't exist. It still fails if
  another table has a ``FOREIGN KEY`` to it, so a file that drops its tables first
  can only be loaded once into the same database.

- A ``FOREIGN KEY`` of a table is added after everything else, so it can refer to
  a table that's created later, and it's checked once all of the rows are there.
  Its line is the line of the table.

- ``PRAGMA`` is ignored. ``BEGIN`` and ``END`` are ``START TRANSACTION`` and
  ``COMMIT``.

Anything else that isn't supported by vsql, such as ``AUTOINCREMENT`` or a column
without a type, is an error.

- ``-verbose`` or ``-v``: When enabled, the output of each statement (such as
  ``CREATE TABLE 1``) will be shown.

module
^^^^^^

``module`` compiles an SQL-client module (with ``LANGUAGE C``) into a C header
and source file next to it, which call libvsql (see :doc:`language-c`):

.. code-block:: sh

   vsql module example.mod     # creates example.h and example.c

If the module has an error, nothing is created and the error is shown, such as
``Error 42601: syntax error: procedure add_item: host parameter :id is not
declared``.

precompile
^^^^^^^^^^

``precompile`` turns an embedded SQL C program (with ``EXEC SQL`` statements)
into a C file next to it, which calls libvsql (see :doc:`language-c`):

.. code-block:: sh

   vsql precompile example.sqc           # creates example.c
   vsql precompile -module example.sqc   # also creates example.mod

If the program has an error, nothing is created and the error is shown, such as
``Error 42601: syntax error: line 12: host variable :id is not defined``.

out
^^^

``out`` will export schema and data in SQL format, or the result of a query as
CSV, TSV or JSON:

.. code-block:: text

   $ vsql out mydatabase.vsql > myfile.sql
   $ cat myfile.sql
   START TRANSACTION;

   CREATE TABLE "PUBLIC"."BAR" (
     "X" INTEGER
   );

   INSERT INTO "PUBLIC"."BAR" ("X") VALUES (1234);

   COMMIT;

The output can be loaded into a new database with the ``in`` command, so it can
be used as a backup. All names are quoted so that their case is kept. Sequences
are restored to the same next value.

Options must be before the file, and are:

- ``-format``: ``sql`` (the default), ``csv``, ``tsv`` or ``json``. All except
  ``sql`` need ``-query``, and ``sql`` can't be used with it.
- ``-file``: Write to this file instead of stdout. If the export fails, the file
  isn't changed.
- ``-include``: Only include the objects that match this pattern. It can be used
  more than once. Without it, all objects are included, which is the same as
  ``*.*``. It's an error if a pattern doesn't match anything.
- ``-exclude``: Leave out the objects that match this pattern, even if they were
  included. It can be used more than once.
- ``-query``: Export the result of a query, instead of the schema and data. It
  can't be used with ``-include`` or ``-exclude``.
- ``-no-header``: With ``csv`` or ``tsv``, leave out the first line of column
  names.
- ``-null``: With ``csv`` or ``tsv``, write ``NULL`` as this instead of leaving
  it empty, such as ``-null '\N'``.
- ``-no-transaction``: With ``sql``, leave out ``START TRANSACTION`` and
  ``COMMIT``. By default they're around the output, so that loading it either
  works or doesn't change anything.
- ``-compat``: With ``sql``, write it for ``vsql`` (the default), ``sqlite3``,
  ``mysql`` or ``postgresql``. See `Loading into another database`_.
- ``-schema-only``: With ``sql``, write only the definitions, without the rows or
  the positions of sequences and identity columns. It can't be used with
  ``-data-only``.
- ``-data-only``: With ``sql``, write only the rows, and the positions of sequences
  and identity columns. The rows are in the order of the table names, so a load
  with foreign keys in place can fail if a table references a table that comes
  after it. SQLite doesn't have this problem. It can't be used with
  ``-schema-only``.
- ``-create-public-schema``: With ``sql``, ``CREATE SCHEMA "PUBLIC";`` will be
  included in the output. By default it is not included because it is provided
  implicitly with a vsql database.

Loading into another database
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``-compat`` writes SQL that can be loaded by another database:

.. code-block:: sh

   $ vsql out -compat sqlite3 mydatabase.vsql | sqlite3 my.db
   $ vsql out -compat mysql mydatabase.vsql | mysql mydb
   $ vsql out -compat postgresql mydatabase.vsql | psql mydb

A name that wasn't delimited is stored in upper case by vsql, and it's written in
lower case, so that ``SELECT * FROM foo`` still works. Other names don't change.
Tables in ``PUBLIC`` go into the default schema of the connection. Other schemas
are ``CREATE SCHEMA`` in PostgreSQL and MySQL (where it's a database). SQLite
doesn't have schemas, so ``foo.bar`` becomes the table ``foo_bar``.

Each database has its own types for these, and any other type doesn't change:

.. list-table::
   :header-rows: 1

   * - vsql
     - ``sqlite3``
     - ``mysql``
   * - ``CHARACTER(n)``, over 255
     -
     - ``VARCHAR(n)``
   * - ``CHARACTER VARYING``, without a length or over 768
     -
     - ``LONGTEXT``
   * - ``REAL``
     -
     - ``FLOAT``
   * - ``DECIMAL`` or ``NUMERIC``, without a precision
     -
     - ``DECIMAL(65, 30)``
   * - ``DATE``
     - ``DATE``, stored as text
     -
   * - ``TIME WITHOUT TIME ZONE``
     - ``TIME``, stored as text
     - ``TIME(p)``
   * - ``TIME WITH TIME ZONE``
     - ``TIME``, stored as text with the offset
     - ``VARCHAR(30)``, so that the offset is kept
   * - ``TIMESTAMP WITHOUT TIME ZONE``
     - ``TIMESTAMP``, stored as text
     - ``DATETIME(p)``
   * - ``TIMESTAMP WITH TIME ZONE``
     - ``TIMESTAMP``, stored as text with the offset
     - ``DATETIME(p)``, stored as UTC

PostgreSQL has all of the types, except that an identity column can't be
``DECIMAL`` or ``NUMERIC``, so it's a ``BIGINT``.

The output always has to load, so anything that the database doesn't have is left
out with a ``--`` comment above the statement it would have been in:

- A sequence, in SQLite and MySQL.
- An identity column becomes ``AUTO_INCREMENT`` in MySQL and ``AUTOINCREMENT`` in
  SQLite, if it's an integer that counts up by 1. In SQLite it also has to be the
  only column of the ``PRIMARY KEY``. Otherwise, it's a normal column that keeps
  its values.
- A ``CHECK`` or generated column that has anything other than columns, literals,
  ``ABS``, ``COALESCE``, ``LOWER``, ``NULLIF``, ``UPPER``, the logical and
  comparison operators, ``+``, ``-``, ``*`` and ``||``. A generated column that's
  left out is a normal column that keeps its values.
- A ``DEFAULT`` of ``CURRENT_CATALOG`` or ``CURRENT_SCHEMA``, in SQLite and MySQL.

These are left out without a comment: ``NOT NULL`` constraint names,
``DEFERRABLE`` and ``INITIALLY DEFERRED`` in SQLite and MySQL (the constraint is
checked immediately), and ``SET DEFAULT`` of a foreign key in MySQL, because InnoDB
doesn't have it.

MySQL needs to be at least 8.0.19. It commits at each ``CREATE`` and ``ALTER``, so
a failed load can't be completely undone, even with the transaction. A key on a
``CHARACTER VARYING`` that's over 768 characters or has no length won't load,
because the key would be too long.

Selecting objects
~~~~~~~~~~~~~~~~~

The patterns of ``-include`` and ``-exclude`` are in the form ``schema.name``,
where each part can have the wildcards ``*``, ``?`` and ``[...]``. Case is
ignored, so there's no way to select ``"foo"`` but not ``FOO``. Remember to quote
them so that they aren't expanded by your shell.

.. code-block:: text

   $ vsql out -include 'sales.*' -exclude '*.tmp_*' mydatabase.vsql

They select sequences, tables (with their rows) and foreign keys, by the name of
each. Other constraints and identity columns are part of their table. A schema
is included if any of its objects are, and a schema with nothing in it is
included unless it's ruled out by the schema of the patterns, such as
``-exclude 'foo.*'``.

Nothing else is added or removed for you, so the output might not load. For
example, leaving out a table doesn't leave out the foreign keys that reference
it, use another ``-exclude`` for those.

``INFORMATION_SCHEMA`` is never included, and it's an error to include it by
name. ``VSQL_APP`` (the tabs and history of ``vsql app``) is included
like any other schema, so use ``-exclude 'VSQL_APP.*'`` to leave it out.

Exporting a query
~~~~~~~~~~~~~~~~~

``-query`` must be one query. It's also how to export a table as CSV, TSV or
JSON, since ``TABLE foo`` is short for ``SELECT * FROM foo``:

.. code-block:: text

   $ vsql out -format csv -query 'TABLE foo' mydatabase.vsql

- ``csv`` follows RFC 4180, with ``\r\n`` at the end of each line. ``tsv`` has
  the same rules, with a tab between values and ``\n`` at the end of each line. A
  ``NULL`` is empty (see ``-null``). A string that's empty, or the same as
  ``-null``, is written in quotes to tell it apart.
- ``json`` is an array of objects with the column names as keys, and each value
  on its own line. Integers are numbers, booleans are ``true`` or ``false``,
  ``NULL`` and ``UNKNOWN`` are ``null``, and everything else is a string as it's
  shown in a result, so decimals stay exact.

Each ``?`` in the query gets its value from an environment variable: ``P1`` for
the first, ``P2`` for the second, and so on. Since the value isn't part of the
SQL, it doesn't need to be escaped:

.. code-block:: text

   $ P1="O'Brien" vsql out -format json -query 'SELECT * FROM t WHERE name = ?' mydatabase.vsql

It's an error if any of them aren't set. A value is always a string, so use a
``CAST`` for anything else, such as ``CAST(? AS INTEGER)``. ``\N`` is ``NULL``, and
a variable that's set but empty is an empty string.

server
^^^^^^

``server`` will start the PostgreSQL-compatible server for a database file. You
may connect to it with one of the :doc:`supported PostgreSQL clients
<postgresql-clients>`. See :doc:`server`.

.. code-block:: text

   $ vsql server mydb.vsql
   ready on 127.0.0.1:3210

Options are:

- ``-host``: Address to listen on (default 127.0.0.1). Use ``0.0.0.0`` or
  ``::`` to accept clients from other machines.
- ``-port`` or ``-p``: Port number (default 3210).
- ``-verbose`` or ``-v``: Verbose (show all messages in and out of the server).

version
^^^^^^^

Is used to display the current version:

.. code-block:: sh

   vsql version
