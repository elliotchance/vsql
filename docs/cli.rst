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

``out`` will export schema and data in SQL format:

.. code-block:: text

   $ vsql out mydatabase.vsql > myfile.sql
   $ cat myfile.sql
   CREATE TABLE "PUBLIC"."BAR" (
     "X" INTEGER
   );

   INSERT INTO "PUBLIC"."BAR" ("X") VALUES (1234);

The output can be loaded into a new database with the ``in`` command, so it can
be used as a backup. All names are quoted so that their case is kept. Sequences
are restored to the same next value.

Options are:

- ``-create-public-schema``: When enabled, ``CREATE SCHEMA "PUBLIC";`` will be
  included in the output. By default it is not included because it is provided
  implicitly with a vsql database.

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
