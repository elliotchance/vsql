CREATE INDEX
============

.. contents::

Syntax
------

.. code-block:: text

  CREATE INDEX <index_name> ON <table_name> ( <column> [ ASC | DESC ] , ... )

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

The values of the columns of each row must fit in half a page (see
:doc:`limitations`), otherwise the statement that creates the index, or that
inserts or updates the row, fails with a ``54000`` error.

``CREATE INDEX`` is a vsql extension, not standard SQL. It's flagged as
``V002-01`` (see :doc:`sql-flagging`).

The first index in a database file raises the *Write Version* of the file (see
:doc:`file-format`), so older versions of vsql (that wouldn't update the index)
can read the file, but not change it.

Examples
--------

.. code-block:: sql

   CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(50), price NUMERIC(10, 2));
   CREATE INDEX products_name ON products (name);
   CREATE INDEX products_price ON products (price DESC, name);
   -- msg: CREATE TABLE 1
   -- msg: CREATE INDEX 1
   -- msg: CREATE INDEX 1

See Also
--------

- :doc:`drop-index`
