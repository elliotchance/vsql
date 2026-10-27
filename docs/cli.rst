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

``app`` starts a web server to browse a database file. Open the address in a
browser to see a SQL editor (run with the button or Ctrl+Enter) that colors the
reserved words. Every statement is run and the result of the last one is shown
below it.

The first tab (the home icon) lists the tables, each with a Query button that
opens a new tab to ``SELECT *`` from it. It's shown when no other tab is active,
and can't be closed.

Each tab has its own SQL, use ``+`` to add a tab (which starts with a query of
``INFORMATION_SCHEMA.TABLES``). The tabs are saved in the ``VSQL_APP.TABS`` table
(created empty the first time) with which tab is active, so they are restored
when the file is opened again. A tab's title is the start of its SQL when it was last
run. Switching tabs doesn't run the SQL, it shows the last result (until the
app is restarted).

.. code-block:: text

   $ vsql app mydb.vsql
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
