DECLARE CURSOR
==============

``DECLARE CURSOR`` names a query, so that its rows can be read one at a time
with :doc:`fetch`, and the row that the cursor is on can be changed with a
positioned :doc:`update` or :doc:`delete` (see :doc:`cursors`).

.. contents::

Syntax
------

.. code-block:: text

  DECLARE <cursor_name> [ SCROLL | NO SCROLL ] CURSOR [ WITH HOLD | WITHOUT HOLD ]
    FOR <query> [ FOR READ ONLY | FOR UPDATE [ OF <column_name> , ... ] ]

The SQL standard only allows ``DECLARE CURSOR`` in an SQL-client module (such
as a C program, see :doc:`language-c`). Running it directly is a vsql extension,
flagged by ``V108-01`` (see :doc:`sql-flagging`).

The query isn't run until the cursor is opened (see :doc:`open`), but it's
checked straight away, so a table that doesn't exist is an error. The values of
any parameters (``?``) are the ones the ``DECLARE CURSOR`` was run with.

A cursor belongs to the connection, and the name can't be declared again
(``42P03``).

WITH HOLD
---------

A cursor is closed when the transaction ends, and a statement outside of a
transaction is its own transaction. So a cursor is usually used inside of
``START TRANSACTION`` (see :doc:`start-transaction`). A ``WITH HOLD`` cursor
stays open after a ``COMMIT``, but not after a ``ROLLBACK``.

SCROLL
------

A ``SCROLL`` cursor can also be fetched in other directions, such as ``PRIOR``
or ``ABSOLUTE``. A cursor that isn't ``SCROLL`` (including ``NO SCROLL``) can
only ``FETCH NEXT``. See "Scrollable Cursors" in :doc:`fetch`.

A ``SCROLL`` cursor is read only unless it's ``FOR UPDATE``. The rows of the
cursor don't change while it's open, so a row that was deleted through the
cursor can be fetched again (but not changed), and a row that was updated
through the cursor is fetched with its old values.

Updatable Cursors
-----------------

A positioned :doc:`delete` or :doc:`update` (``WHERE CURRENT OF``) needs a
cursor that is updatable. A cursor is updatable if it selects from one table
(without a join, ``GROUP BY``, aggregate function, ``DISTINCT``, ``OFFSET`` or
``FETCH FIRST``), unless it's ``FOR READ ONLY``. A cursor with an ``ORDER BY``,
or a ``SCROLL`` cursor, is only updatable with ``FOR UPDATE``. ``FOR UPDATE OF``
limits the columns that a positioned ``UPDATE`` can change. A positioned
``UPDATE`` also can't change a column that's used by a sort key of the
``ORDER BY`` (``42601``).

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);

  START TRANSACTION;
  DECLARE c CURSOR FOR SELECT * FROM products;
  OPEN c;
  FETCH c;
  CLOSE c;
  COMMIT;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: START TRANSACTION
  -- msg: DECLARE CURSOR
  -- msg: OPEN
  -- NAME: Coffee PRICE: 4.50
  -- msg: CLOSE
  -- msg: COMMIT

See Also
--------

- :doc:`cursors`
- :doc:`open`
- :doc:`fetch`
- :doc:`close`
