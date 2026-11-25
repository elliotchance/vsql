VACUUM
======

.. contents::

Syntax
------

.. code-block:: text

  VACUUM [ ON <object> ... ] [ <option> ... ]

  <object> ::=
      ALL
    | CATALOG <catalog name>
    | SCHEMA <schema name>
    | TABLE <table name> [ { WITH | WITHOUT } INDEXES ]
        [ { WITH | WITHOUT } LARGE OBJECTS ]
    | INDEX <index name>

  <option> ::=
      COMPACT
    | FULL
    | FREE PAGES
    | TIMEOUT <seconds>

Make the database files of the catalogs smaller.

A database file never gets smaller on its own. The pages that are no longer
needed (such as after a ``DELETE`` or ``DROP TABLE``) are kept for the rows that
are added next (see :doc:`file-format`), and the pages that are left are often
only partly full. ``VACUUM`` puts the rows, index entries and large values into
fewer pages, and makes the file shorter.

Nothing that can be seen changes: the rows, tables, indexes and sequences are
the same. Reading the database can be faster afterwards, because there are
fewer pages to read.

The options can be in any order, but each can only be given once, and only one
of ``COMPACT``, ``FULL`` and ``FREE PAGES`` (otherwise it's a ``42601``
error).

Objects
^^^^^^^

The objects come after ``ON``, such as ``VACUUM ON TABLE foo TABLE bar``.
Without any objects, it's ``ALL``: every catalog of the connection (each one is
its own file, see :doc:`set-catalog`). Otherwise, only the pages of the objects
are packed, but the file of each of their catalogs is always shrunk (see
`COMPACT`_):

- ``CATALOG`` is every object of a catalog. The name is an identifier, so it
  must be delimited if it isn't upper case (such as ``CATALOG ":memory:"``).
- ``SCHEMA`` is every table of a schema, with their indexes and large objects.
- ``TABLE`` is the rows of a table, and its indexes and large values, unless
  they're ``WITHOUT INDEXES`` or ``WITHOUT LARGE OBJECTS`` (in either order).
- ``INDEX`` is only the entries of an index.

The names are found the same way as any other name, so a table or index without
a schema is in the current schema of the current catalog. It's an error if the
table (``42P01``), index (``42704``), schema (``3F000``) or catalog (``3D000``)
doesn't exist, which is checked before anything is changed. The objects can
overlap (such as ``ON TABLE a INDEX a_v``), but ``ALL`` must be on its own, and
``WITH`` or ``WITHOUT`` can only be given once for each of ``INDEXES`` and
``LARGE OBJECTS`` (otherwise it's a ``42601`` error).

Packing only some of the objects is quicker than packing every object, such as
for a table that has a lot of rows replaced while the others don't change. The
pages at the start and end of an object may also have the objects of another
table or index, which are packed as well.

COMPACT
^^^^^^^

``COMPACT`` is the default. It does two things:

1. The objects of each page of the B-tree are moved into the page before it
   while they fit, and a page that's left empty is freed. Only the pages that
   have the same parent page are packed together, so the pages aren't always
   as full as ``FULL`` makes them.

2. The pages at the end of the file are moved into the free pages, and the file
   is cut after the last page that's used. Afterwards, there are no free pages.

Both are done in batches of about 1,000 pages, each of which is committed on its
own, so other connections can read and change the database in between, and it
doesn't need much memory.

FULL
^^^^

``FULL`` can only be used for ``ALL`` or a ``CATALOG``. It copies every row, index entry and large value into new pages that are
as full as possible, in order, which replace every page of the file. The file is
as small as it can be, but it's done in one go: the other connections wait for
it, and it needs about as much memory as the size of the rebuilt file (and as
much disk space again for the log). The file isn't changed when it wouldn't have
fewer pages, which can happen when there's nothing to remove, because a large
value is split into pieces of half a page that can't be packed any closer.

FREE PAGES
^^^^^^^^^^^^^^^

``FREE PAGES`` only does the second step of ``COMPACT``: the free pages are
removed from the file, but the pages that are only partly full aren't packed. It
reads very little of the file, so it's the quickest way to give back the space
of rows that were deleted.

Result
^^^^^^

The result is ``VACUUM`` followed by the number of pages that were read (and
moved), and the number of pages that were removed from the files, such as
``VACUUM 2400 2150``. What was done to each object is in ``VSQL.LAST_VACUUM``
(see `LAST_VACUUM`_).

TIMEOUT
^^^^^^^

``TIMEOUT`` is the most seconds (such as ``30`` or ``0.5``) that it should take.
Once the time is up, it stops after the batch that it's in, and keeps what it
has done. That isn't an error, the result counts only what was done (and
``LAST_VACUUM`` shows what wasn't finished). ``FULL`` isn't done in batches, so
it's either finished or doesn't change anything.

LAST_VACUUM
-----------

``VSQL.LAST_VACUUM`` is a view of what the last ``VACUUM`` of the connection
did (see :doc:`vsql-schema`). It can be read like any other view, such as to
filter it, or to copy it into a table, including in a transaction:

.. code-block:: sql

  VACUUM;
  START TRANSACTION;
  CREATE TABLE vac AS (SELECT * FROM vsql.last_vacuum) WITH DATA;
  SELECT object_name, SUM(pages_read) FROM vac
  WHERE object_schema = 'PUBLIC' GROUP BY object_name;
  COMMIT;

The rows belong to the connection, and are only kept in memory: another
connection (such as another client of a :doc:`server <server>`) has its own, and
they're gone when the connection is closed. The next ``VACUUM`` replaces them.
They're empty before the first ``VACUUM`` of the connection, and after a
``VACUUM`` that fails, and they aren't changed by a ``COMMIT`` or ``ROLLBACK``.
``LAST_VACUUM`` is the same in every catalog, with the rows of every catalog
that the ``VACUUM`` was of. It's read-only.

There's a row for each table, each index and the large values of each table that
had pages packed (or that weren't finished), in order of their names, and then a
row for the file, for each catalog. The columns are named and typed like the
views of the ``INFORMATION_SCHEMA`` (see :doc:`information-schema`):

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``OBJECT_CATALOG``, ``OBJECT_SCHEMA``, ``OBJECT_NAME``
    - The table or index. ``OBJECT_SCHEMA`` and ``OBJECT_NAME`` are ``NULL``
      for the file.

  * - ``OBJECT_TYPE``
    - ``TABLE`` (its rows), ``INDEX``, ``LARGE OBJECTS`` (the large values of a
      table) or ``FILE``.

  * - ``PAGES_READ``
    - The pages that were read to pack the object. For the file, the pages that
      were moved into free pages (or read by ``FULL``).

  * - ``PAGES_FREED``
    - The pages of the object that were left empty, and freed. For the file,
      the pages that were removed from the file.

  * - ``IS_FINISHED``
    - ``NO`` if the ``TIMEOUT`` ran out before the object was packed (for the
      file, before every free page was removed), otherwise ``YES``.

The numbers are counted while the pages are packed, so ``VACUUM`` doesn't read
any more pages for them. ``FULL`` and ``FREE PAGES`` don't pack the objects, so
there's only the row for the file.

For ``ALL`` or a ``CATALOG``, a page is counted for the table or index of its
first row or entry. A page that only has the definitions of the schema isn't
counted for any object, so ``PAGES_READ`` can add up to less than the first
number of the result. When the ``TIMEOUT`` runs out, an object that wasn't
reached doesn't have a row. Otherwise, each page that's read for an object is
counted for it, including the pages at its start and end that it shares with
another table or index.

Reading ``LAST_VACUUM`` is flagged as ``V004-02`` (see :doc:`sql-flagging`).

Transactions
------------

``VACUUM`` doesn't need the database to be taken offline. It can run while
other connections (such as the clients of a :doc:`server <server>`) are still
connected and have transactions. Every version of every row is kept, including
the rows that a transaction has added, changed or deleted and hasn't committed
yet, so the transaction can still ``COMMIT`` or ``ROLLBACK`` afterwards, and a
``REPEATABLE READ`` transaction still sees the rows it saw before. So the pages
of the rows that a transaction is still using can't be removed until it ends.

Like any other statement that changes the database, each batch waits for a
``SERIALIZABLE`` transaction that has changed the database to end, since that
transaction has the file to itself until then (it's a ``40001`` error after
the lock timeout, see :doc:`transactions`). It doesn't wait for a ``READ
COMMITTED`` or ``REPEATABLE READ`` transaction, or a transaction that has only
read.

``VACUUM`` itself can't be in a transaction (that's a ``25001`` error), because
it changes pages, rather than rows, which can't be undone by a ``ROLLBACK``.
Like any other statement, each batch is written through the write-ahead log, so
if the process stops, the file has every batch that was committed, and none of
the batch that wasn't.

On ``:memory:`` it packs the pages in memory.

``VACUUM`` is a vsql extension, not standard SQL. It's flagged as ``V004-01``
(see :doc:`sql-flagging`).

Examples
--------

.. code-block:: sql

   CREATE TABLE events (id INT PRIMARY KEY, body VARCHAR(100));
   DELETE FROM events;
   VACUUM;
   VACUUM FREE PAGES TIMEOUT 5;
   VACUUM ON TABLE events WITHOUT INDEXES;
   -- msg: CREATE TABLE 1
   -- msg: DELETE 0
   -- msg: VACUUM 1 0
   -- msg: VACUUM 0 0
   -- msg: VACUUM 1 0

See Also
--------

- :doc:`file-format`
