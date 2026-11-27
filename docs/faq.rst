FAQ
===

.. contents::
   :local:
   :depth: 2

General
-------

What is vsql?
^^^^^^^^^^^^^

An embedded SQL database that follows the SQL standard. A whole database lives
in a single file (or in memory) and runs inside your program, so there's no
server to install or manage. It's written in V, and the ``vsql`` command is a
single binary with nothing else to install. See :doc:`quick-start`.

How is vsql different from SQLite?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It's used the same way (one file, no server), but it behaves like a
client/server SQL database: types are strict, ``NUMERIC`` is exact, there are
real ``DATE``, ``TIME`` and ``TIMESTAMP`` types, and the SQL is the standard
rather than its own dialect. Many connections (including ones in other
processes) can use a file at the same time (see :doc:`mvcc`).
:doc:`compatibility-sqlite3` lists each SQLite function and what to use instead.

Is the file format stable? Will new versions open my database?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Yes. Every version of vsql can open a file created by an older version. A file
that uses a feature from a newer version may only be readable (or not open at
all) in an older version. See :ref:`file-format:Compatibility`.

What's the licence?
^^^^^^^^^^^^^^^^^^^

MIT. You can use it in open source and commercial software.

Which platforms does it run on?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There are prebuilt binaries for Linux, macOS and Windows, on x86-64 and ARM64.
For anything else, build it from the C amalgamation with your own compiler. See
:doc:`install`.

Installing and Using
--------------------

How do I install or update vsql?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

On Linux or macOS, run the install script, or download a zip from the latest
release. ``vsql up`` updates it to the latest release. There's also a Docker
image, and ``v install elliotchance.vsql`` for V programs. See :doc:`install`.

Which languages can use it?
^^^^^^^^^^^^^^^^^^^^^^^^^^^

V (see :doc:`language-v`) and C or C++ (see :doc:`language-c`). There are also
libraries for Go, Python, Java, Rust, Node.js and Swift (see
:doc:`embedding`).
Any other language that can connect to PostgreSQL can use :doc:`server`.

Can I use a GUI or a PostgreSQL client?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Yes. ``vsql server`` lets PostgreSQL clients (such as ``psql``, DBeaver and
TablePlus) connect to a database file (see :doc:`server` and
:doc:`postgresql-clients`). ``vsql app`` lets you browse and query a database in
your browser (see :ref:`cli:app`).

Can I use a database that's only in memory?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Yes, open the file name ``:memory:``, such as ``vsql cli :memory:``. Nothing is
written to disk, and the database is gone when the connection is closed. See
:doc:`in-memory-database`.

How do I load data from a CSV file or from SQLite?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``vsql in`` loads a file of SQL statements, or a CSV, TSV or JSON file into a
table (see :ref:`cli:in`). With ``-compat sqlite3`` it loads the output of
SQLite's ``.dump`` (see :ref:`cli:Loading a SQLite file`).

How do I see which tables exist?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Query the standard ``INFORMATION_SCHEMA`` views (see
:doc:`information-schema`):

.. code-block:: sql

   SELECT table_schema, table_name
   FROM information_schema.tables
   WHERE table_schema <> 'INFORMATION_SCHEMA';

``vsql out`` prints the ``CREATE`` statement of everything in a database file
(see :ref:`cli:out`). From V, ``Connection.catalog()`` lists the schemas,
tables and sequences.

SQL
---

Why are my table and column names in upper case?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The SQL standard converts a name that isn't quoted to upper case, so ``foo``,
``Foo`` and ``FOO`` are all the name ``FOO``. A name in double quotes keeps its
case, so ``"Foo"`` is a different name than ``FOO``, and must always be written
as ``"Foo"``. This applies to every name, including the ``AS`` name of a column:

.. code-block:: sql

   SELECT 1 + 2 AS "the Total";
   -- the Total: 3

See :doc:`identifiers`.

A name in double quotes can contain any character except control and format
characters (such as a tab), unassigned code points, and line and paragraph
separators. A double quote is written twice, so ``"say ""hi"""`` is the name
``say "hi"``. It can't be empty (``""``).

Why does a query that works in PostgreSQL, MySQL or SQLite fail?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

vsql follows the SQL standard rather than another database's dialect, and its
types are strict, so ``'a' || 1`` is an error rather than ``'a1'`` (use
``CAST(1 AS VARCHAR(10))``). :doc:`compatibility` lists every function of
PostgreSQL, MySQL and SQLite, and how to get the same result in vsql.
:doc:`sql-compliance` lists which parts of the standard are supported.

How do I make an auto-incrementing column?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Use an identity column, which is the standard version of ``SERIAL`` or
``AUTO_INCREMENT`` (see :ref:`create-table:Identity Columns`):

.. code-block:: sql

   CREATE TABLE orders (
     id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
     item VARCHAR(20)
   );
   INSERT INTO orders (item) VALUES ('Coffee'), ('Bagel');
   SELECT * FROM orders;
   -- ID: 1 ITEM: Coffee
   -- ID: 2 ITEM: Bagel

A sequence can also be shared by several tables (see :doc:`create-sequence`).

Which parts of my SQL only work in vsql?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

vsql has some extensions to the standard, such as ``CREATE INDEX``, ``EXPLAIN``
and ``LIMIT``. ``features()`` of a prepared statement in V lists the optional
features of the standard (and the vsql extensions) that a statement uses, so you
can find the SQL that won't work in another database. See :doc:`sql-flagging`.

Does vsql support JSON?
^^^^^^^^^^^^^^^^^^^^^^^

Not yet. There's no ``JSON`` type and none of the SQL/JSON functions, but JSON
can be stored as text (see :ref:`compatibility-sqlite3:JSON Functions`). ``vsql
in`` and ``vsql out`` can import and export JSON files (see :doc:`cli`).

How do dates and time zones work?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``TIME`` and ``TIMESTAMP`` can be ``WITH TIME ZONE`` or ``WITHOUT TIME ZONE``. A
time zone is an offset from UTC, such as ``+05:30``. Names of time zones (such
as ``Europe/London``) aren't supported. Each connection starts in the local time
zone of the computer, which :doc:`set-time-zone` changes. See
:doc:`dates-times`.

Where can I find the SQL standard?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The SQL standard is not free. However, older versions are publicly available
and are close enough to use as a reference:

1. `SQL 2016 Foundation Grammar (BNF) <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_
2. `SQL 1999 <https://sql-99.readthedocs.io/en/latest/>`_

See also :doc:`sql-standard`.

Transactions and Data
---------------------

Can several processes or threads use the same database file?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Yes. Many connections, in the same process or in different processes, can use a
file at the same time. Give each thread its own connection. A statement only
locks the file while it runs, and a query outside of a transaction never waits
for one that changes the database. Up to 256 transactions can be active at the
same time. See :doc:`transactions`, :doc:`locking` and :doc:`mvcc`.

What's the default isolation level?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``SERIALIZABLE``, the default of the SQL standard. Only one ``SERIALIZABLE``
transaction that changes the database can be active at a time, and another one
waits for it to finish. All four standard levels are supported. See
:ref:`transactions:Isolation Levels`.

Why did my transaction fail with ``40001``?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A ``40001`` serialization failure means another transaction got in the way, such
as by changing the same row, or by holding up a ``SERIALIZABLE`` transaction for
longer than the lock timeout (5 seconds by default). The transaction has been
rolled back, so it can be retried. See :doc:`transactions` and :doc:`sqlstate`.

Is my data safe if the process crashes or the power fails?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A write-ahead log (the ``.wal`` file next to the database) is synced to the
disk when each statement or transaction is committed, and a transaction that
didn't finish is rolled back by the next connection. On macOS, a power failure
can still lose recent changes (or leave the file corrupt) unless the
``full_fsync`` connection option is used. See :doc:`durability`.

How do I back up a database?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``vsql out`` writes the whole database as SQL, which ``vsql in`` loads into a
new database (see :ref:`cli:out`). You can also copy the file when no connection
has it open. If there's a ``.wal`` file next to it, copy that too. See
:doc:`durability`.

How big can a database be?
^^^^^^^^^^^^^^^^^^^^^^^^^^

Up to 8 TB with the default page size (128 TB with the largest), with up to 1600
columns in a table. See :doc:`limitations`.

How fast is it?
^^^^^^^^^^^^^^^

Run ``vsql bench`` to measure it on your own machine, with TPC-B transactions
or SQLite's ``speedtest1`` (see :doc:`benchmark`).
``EXPLAIN`` shows how a query will be run (see :doc:`explain`), and
:doc:`create-index` speeds up a query that searches a large table.

Getting Help
------------

How do I report a bug or ask a question?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Open a `GitHub issue <https://github.com/elliotchance/vsql/issues>`_, with the
SQL that shows the problem and the output of ``vsql version``. Errors have a
standard SQLSTATE code, which :doc:`sqlstate` explains.

How can I contribute?
^^^^^^^^^^^^^^^^^^^^^

See :doc:`contributing` for how to build vsql, run the tests and send a pull
request.
