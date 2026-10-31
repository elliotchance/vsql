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

``in`` is used to load a SQL file into a database:

.. code-block:: text

   $ vsql in mydatabase.vsql < myfile.sql
   0 errors, 8 statements, 98.042ms

You can generate a valid SQL file from an existing database with ``vsql out``.

Options are:

- ``-continue-on-error``: Show errors, but continue to process the input. A
  non-zero exit code will be returned if any of the statements failed.

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
