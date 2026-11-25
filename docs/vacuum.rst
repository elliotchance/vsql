VACUUM
======

.. contents::

Syntax
------

.. code-block:: text

  VACUUM [ <option> ... ]

  <option> ::=
      COMPACT
    | FULL
    | FREE PAGES
    | VERBOSE
    | TIMEOUT <seconds>

Make the database file of the current catalog smaller.

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

``FULL`` copies every row, index entry and large value into new pages that are
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

VERBOSE
^^^^^^^

Without ``VERBOSE``, the result is ``VACUUM`` followed by the number of pages
that were read (and moved), and the number of pages that were removed from the
file, such as ``VACUUM 2400 2150``.

With ``VERBOSE``, there's a row for each table, each index, and the large values
of each table (that have pages), and then a row for the file:

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``CATALOG``, ``SCHEMA``, ``NAME``
    - The table or index. ``SCHEMA`` and ``NAME`` are ``NULL`` for the file.

  * - ``KIND``
    - ``TABLE`` (its rows), ``INDEX``, ``LARGE OBJECTS`` (the large values of a
      table) or ``FILE``.

  * - ``PAGES``
    - The leaf pages before (every page of the file, including free pages, for
      the file).

  * - ``FILL``
    - How full those pages were, as a percentage of their bytes.

  * - ``PAGES_AFTER``
    - The leaf pages after (every page of the file, for the file).

  * - ``FINISHED``
    - ``FALSE`` if the ``TIMEOUT`` ran out before it was packed (for the file,
      before every free page was removed).

A page that has the objects of more than one table or index is counted for the
first one.

TIMEOUT
^^^^^^^

``TIMEOUT`` is the most seconds (such as ``30`` or ``0.5``) that it should take.
Once the time is up, it stops after the batch that it's in, and keeps what it
has done. That isn't an error, the result counts only what was done (and
``VERBOSE`` shows what wasn't ``FINISHED``). ``FULL`` isn't done in batches, so
it's either finished or doesn't change anything.

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
   -- msg: CREATE TABLE 1
   -- msg: DELETE 0
   -- msg: VACUUM 1 0
   -- msg: VACUUM 0 0

See Also
--------

- :doc:`file-format`
