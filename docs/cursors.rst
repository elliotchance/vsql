Cursors
=======

A cursor reads the rows of a query one at a time, and can change (or delete)
the row that it's on.

.. contents::

Syntax
------

.. code-block:: text

  DECLARE <cursor_name> CURSOR [ WITH HOLD | WITHOUT HOLD ]
    FOR <query> [ FOR READ ONLY | FOR UPDATE [ OF <column_name> , ... ] ]

  OPEN <cursor_name>

  FETCH [ [ NEXT ] FROM ] <cursor_name>

  CLOSE <cursor_name>

  DELETE FROM <table_name> WHERE CURRENT OF <cursor_name>

  UPDATE <table_name>
  SET <column_name> = <value> , ...
  WHERE CURRENT OF <cursor_name>

The SQL standard only allows these statements in an SQL-client module (such as
a C program, see :doc:`language-c`). Running them directly is a vsql extension
(see :doc:`sql-flagging`), so ``FETCH`` returns the row instead of putting its
values into variables.

DECLARE CURSOR
--------------

``DECLARE CURSOR`` names a query. The query isn't run until the cursor is
opened, but it's checked straight away, so a table that doesn't exist is an
error. The values of any parameters (``?``) are the ones the ``DECLARE CURSOR``
was run with.

A cursor belongs to the connection, and the name can't be declared again
(``42P03``).

OPEN, FETCH and CLOSE
---------------------

``OPEN`` runs the query, and the cursor is positioned before the first row.
Each ``FETCH`` moves to the next row and returns it. After the last row,
``FETCH`` returns no rows, with the completion condition ``02000`` (no data).

``CLOSE`` closes the cursor, which can then be opened again. A cursor that's
already open can't be opened, and a cursor that isn't open can't be fetched or
closed (``24000``).

A cursor is closed when the transaction ends, and a statement outside of a
transaction is its own transaction. So a cursor is usually used inside of
``START TRANSACTION``. A ``WITH HOLD`` cursor stays open after a ``COMMIT``, but
not after a ``ROLLBACK``.

Positioned DELETE and UPDATE
----------------------------

``DELETE ... WHERE CURRENT OF`` deletes the row that the cursor is on. The cursor
is then before the next row, so it has to be fetched again before another
positioned ``DELETE`` or ``UPDATE``. ``UPDATE ... WHERE CURRENT OF`` updates the
row, and the cursor stays on it.

The cursor must be updatable. A cursor is updatable if it selects from one table
(without a join, ``GROUP BY``, aggregate function, ``DISTINCT``, ``OFFSET`` or
``FETCH FIRST``), unless it's ``FOR READ ONLY``. A cursor with an ``ORDER BY``
is only updatable with ``FOR UPDATE``. ``FOR UPDATE OF`` limits the columns that
a positioned ``UPDATE`` can change.

The rows of a cursor are found when it's opened, so a ``FETCH`` returns the row
as it was then, even if it has been changed since. A row that has been deleted
can't be changed through the cursor (``24000``). A ``WITH HOLD`` cursor must be
fetched in the current transaction before its row can be changed.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);

  START TRANSACTION;
  DECLARE c CURSOR FOR SELECT * FROM products;
  OPEN c;
  FETCH c;
  UPDATE products SET price = 5.00 WHERE CURRENT OF c;
  FETCH c;
  DELETE FROM products WHERE CURRENT OF c;
  FETCH c;
  CLOSE c;
  COMMIT;

  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: START TRANSACTION
  -- msg: DECLARE CURSOR
  -- msg: OPEN
  -- NAME: Coffee PRICE: 4.50
  -- msg: UPDATE 1
  -- NAME: Bagel PRICE: 2.25
  -- msg: DELETE 1
  -- warning 02000: no data
  -- msg: CLOSE
  -- msg: COMMIT
  -- NAME: Coffee PRICE: 5.00
