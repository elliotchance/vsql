CREATE INDEX
============

.. contents::

Syntax
------

.. code-block:: text

  CREATE [ UNIQUE ] INDEX <index_name> ON <table_name> ( <column> [ ASC | DESC ] , ... )

Create an index on one or more columns of a table. An index keeps a copy of the
values of the columns in order, with a reference to each row, and it's kept up
to date as rows are inserted, updated and deleted.

A ``SELECT``, ``UPDATE`` or ``DELETE`` uses an index to read only the rows that
its ``WHERE`` clause can be true for, when the ``WHERE`` clause compares the
first columns of the index with a value (such as ``=``, ``<``, ``>=`` or
``BETWEEN``), joined by ``AND``. See :doc:`explain` for how the index (or the
``PRIMARY KEY``) is chosen.

The index is always in the schema of the table, so its name can't be qualified.
The name must be unique among the indexes of the schema, but it can be the same
as the name of a table, sequence or constraint. A column can only be in the
index once. ``ASC`` (the default) or ``DESC`` is the order of the values of the
column in the index. ``NULL`` is before any other value, like ``ORDER BY`` (or
after them for ``DESC``).

``CREATE INDEX`` can't include the rows that another transaction has inserted,
updated or deleted and not committed yet. So it waits for those transactions to
finish, for up to 60 seconds (``create_index_timeout`` in the connection
options), and then fails with a ``55P03`` error. Until a transaction that
creates or drops an index commits, other transactions can't change the table
(they get a ``40001`` serialization failure).

With ``UNIQUE``, no two rows can have the same values for the columns of the
index, unless any of them are ``NULL`` (like a ``UNIQUE`` constraint). The
``INSERT`` or ``UPDATE`` that would make two rows the same fails with a
``23505`` error. That's checked once all of the rows of the statement have been
changed, so ``UPDATE t SET u = u + 1`` works. ``CREATE UNIQUE INDEX`` fails in
the same way if two rows are already the same.

Constraints
^^^^^^^^^^^

A ``UNIQUE`` constraint (see :doc:`create-table` and :doc:`alter-table`) always
has its own ``UNIQUE`` index, with the same name as the constraint, on the
columns of the constraint. It's created and dropped with the constraint, and it
can't be dropped with ``DROP INDEX``. The constraint is checked with the index,
rather than by reading every row of the table.

A ``FOREIGN KEY`` uses an index whose first columns are its columns (in any
order) to find the rows that reference a row, such as when the row is deleted.
If the table doesn't have one, it gets one with the same name as the
``FOREIGN KEY``. That index can't be dropped while it's the only one that the
``FOREIGN KEY`` can use, but it's kept as an ordinary index when the
``FOREIGN KEY`` is dropped. The referenced row is found by its ``PRIMARY KEY``,
or the index of its ``UNIQUE`` constraint.

So a new constraint can't have the same name as an index in the schema (that's
a ``42P07`` error), and a constraint without a name gets a name that isn't the
name of an index. A table from an older version of vsql gets the indexes of its
constraints the first time they're needed, which raises the *Write Version* of
the file (see below).

These indexes are used to find rows like any other index.

Limits
^^^^^^

The values of the columns of each row must fit in half a page (see
:doc:`limitations`), otherwise the statement that creates the index, or that
inserts or updates the row, fails with a ``54000`` error.

``CREATE INDEX`` is a vsql extension, not standard SQL. It's flagged as
``V002-01``, and ``UNIQUE`` as ``V002-02`` (see :doc:`sql-flagging`).

The first index in a database file raises the *Write Version* of the file (see
:doc:`file-format`), so older versions of vsql (that wouldn't update the index)
can read the file, but not change it.

Examples
--------

.. code-block:: sql

   CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(50), price NUMERIC(10, 2));
   CREATE INDEX products_name ON products (name);
   CREATE INDEX products_price ON products (price DESC, name);
   CREATE UNIQUE INDEX products_name_unique ON products (name);
   INSERT INTO products (id, name, price) VALUES (1, 'Pen', 1.5), (2, 'Pen', 2);
   -- msg: CREATE TABLE 1
   -- msg: CREATE INDEX 1
   -- msg: CREATE INDEX 1
   -- msg: CREATE INDEX 1
   -- error 23505: violates unique constraint: UNIQUE INDEX PRODUCTS_NAME_UNIQUE on ":memory:".PUBLIC.PRODUCTS

See Also
--------

- :doc:`drop-index`
