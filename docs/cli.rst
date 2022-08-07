Command Line Interface (CLI)
============================

.. contents::

Installing
----------

Binary releases can be downloaded from the
`Releases <https://github.com/elliotchance/vsql/releases>`_ page (under Assets).

These binary releases do not require V to be installed.

Compiling From Source
---------------------

You can compile from source with:

.. code-block:: sh

   make bin/vsql       # macOS and linux
   make bin/vsql.exe   # windows

Commands
--------

bench
^^^^^

``bench`` is used to run benchmarks:

.. code-block:: sh

   vsql bench                    # on disk
   vsql bench -file ':memory:'   # in memory

cli
^^^

``cli`` provides a command prompt for running SQL commands (ctrl+c to exit):

.. code-block:: text

   $ vsql cli test.vsql
   vsql> select * from foo;
   A: 1234 
   1 row (1 ms)

   vsql> select * from bar;
   0 rows (0 ms)

in
^^^

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
   CREATE TABLE PUBLIC.BAR (
      X INTEGER
   );

   INSERT INTO PUBLIC.BAR (X) VALUES (1234);

The output can be loaded into a database with the ``in`` command.

Options are:

- ``-create-public-schema``: When enabled, ``CREATE SCHEMA PUBLIC;`` will be
  included in the output. By default it not included because it is provided
  implicitly with a vsql database.

server
^^^^^^

``server`` will start the PostgreSQL-compatible server. You may connect to it
with on of the :doc:`supported PostgreSQL clients here<postgresql-clients>`.

.. code-block:: sh

   vsql server

Options are:

- ``--port`` or ``-p``: Port number (default 3210).
- ``--verbose`` or ``-v``: Verbose (show all messages in and out of the server).

version
^^^^^^^

Is used to display the current version:

.. code-block:: sh

   vsql version
