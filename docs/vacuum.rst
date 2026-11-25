VACUUM
======

.. contents::

Syntax
------

.. code-block:: text

  VACUUM

Rebuild the database file of the current catalog so that it's as small as it
can be.

A database file never gets smaller on its own. The pages that are no longer
needed (such as after a ``DELETE`` or ``DROP TABLE``) are kept for the rows that
are added next (see :doc:`file-format`). ``VACUUM`` writes every row, index and
large value into new pages that are as full as possible, in order, and the file
is made shorter. There are no free pages afterwards.

The result is ``VACUUM`` followed by the number of pages that were scanned, and
the number of pages that were removed from the file, such as ``VACUUM 2400
2150``. The pages that are scanned are the pages of the B-tree that hold the
data, so free pages aren't scanned, but they're included in the pages that are
removed. The file isn't changed when it wouldn't have fewer pages (the result
is ``VACUUM 2400 0``), which can happen when there's nothing to remove, because
a large value is split into pieces of half a page that can't be packed any
closer.

Nothing that can be seen changes: the rows, tables, indexes and sequences are
the same. Reading the database can be faster afterwards, because there are
fewer pages to read.

``VACUUM`` can't be in a transaction (that's a ``25001`` error), and it's a
``40001`` error if another connection has a transaction. Like any other
statement, it's written through the write-ahead log, so the file is either
rebuilt or unchanged if the process stops.

The new pages are kept in memory until they're written, so it needs about as
much memory as the size of the rebuilt file, and as much disk space again for
the log. On ``:memory:`` it rebuilds the pages in memory.

``VACUUM`` is a vsql extension, not standard SQL. It's flagged as ``V004-01``
(see :doc:`sql-flagging`).

Examples
--------

.. code-block:: sql

   CREATE TABLE events (id INT PRIMARY KEY, body VARCHAR(100));
   DELETE FROM events;
   VACUUM;
   -- msg: CREATE TABLE 1
   -- msg: DELETE 0
   -- msg: VACUUM 1 0

See Also
--------

- :doc:`file-format`
