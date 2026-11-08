Cursors
=======

A cursor reads the rows of a query one at a time, and can change (or delete)
the row that it's on.

.. contents::

Syntax
------

.. code-block:: text

  DECLARE <cursor_name> [ SCROLL | NO SCROLL ] CURSOR [ WITH HOLD | WITHOUT HOLD ]
    FOR <query> [ FOR READ ONLY | FOR UPDATE [ OF <column_name> , ... ] ]

  OPEN <cursor_name>

  FETCH [ [ <orientation> ] FROM ] <cursor_name>

  <orientation> ::=
      NEXT
    | PRIOR
    | FIRST
    | LAST
    | ABSOLUTE <number>
    | RELATIVE <number>

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

Scrollable Cursors
------------------

A ``SCROLL`` cursor can also be fetched in other directions. A cursor that
isn't ``SCROLL`` (including ``NO SCROLL``) can only ``FETCH NEXT``, any other
direction is an error (``42601``).

- ``NEXT`` is the row after the cursor (the default).
- ``PRIOR`` is the row before the cursor.
- ``FIRST`` and ``LAST`` are the first and last rows.
- ``ABSOLUTE n`` is the ``n``-th row, starting at 1. A negative ``n`` counts
  from the end, so ``ABSOLUTE -1`` is the last row.
- ``RELATIVE n`` moves ``n`` rows forward, or backward if ``n`` is negative.
  ``RELATIVE 0`` fetches the current row again.

``n`` must be an integer literal (an exact numeric with scale 0, otherwise it's
a ``42601`` error).

When there's no such row the ``FETCH`` returns no rows (``02000``), and the
cursor is after the last row if it was moving forward (``NEXT``, ``LAST``, or
past the end with ``ABSOLUTE`` or ``RELATIVE``), or otherwise before the first
row. So, for example, a ``PRIOR`` after the cursor has gone past the end
fetches the last row. ``RELATIVE 0`` doesn't move the cursor.

A ``SCROLL`` cursor is read only unless it's ``FOR UPDATE``. The rows of the
cursor don't change while it's open, so a row that was deleted through the
cursor can be fetched again (but not changed), and a row that was updated
through the cursor is fetched with its old values.

Positioned DELETE and UPDATE
----------------------------

``DELETE ... WHERE CURRENT OF`` deletes the row that the cursor is on. The cursor
is then before the next row, so it has to be fetched again before another
positioned ``DELETE`` or ``UPDATE``. ``UPDATE ... WHERE CURRENT OF`` updates the
row, and the cursor stays on it.

The cursor must be updatable. A cursor is updatable if it selects from one table
(without a join, ``GROUP BY``, aggregate function, ``DISTINCT``, ``OFFSET`` or
``FETCH FIRST``), unless it's ``FOR READ ONLY``. A cursor with an ``ORDER BY``,
or a ``SCROLL`` cursor, is only updatable with ``FOR UPDATE``. ``FOR UPDATE OF`` limits the columns that
a positioned ``UPDATE`` can change. A positioned ``UPDATE`` also can't change a
column that's used by a sort key of the ``ORDER BY`` (``42601``).

The rows of a cursor are found when it's opened, so a ``FETCH`` returns the row
as it was then, even if it has been changed since. A ``WITH HOLD`` cursor must
be fetched in the current transaction before its row can be changed.

A positioned ``DELETE`` or ``UPDATE`` raises the warning ``01001`` (see
:doc:`sqlstate`) if the current row has been changed by another statement since
the cursor was opened. A row that has been updated is still changed. A row that
has been deleted can't be, so the statement changes no rows. The warning is also
raised by a searched ``DELETE`` or ``UPDATE`` (or a referential action) that
changes a row that a positioned ``UPDATE`` of a cursor that's still open has
already changed. That's only for the cursors of the same connection.

SQL/CLI
-------

In the SQL/CLI (see :doc:`language-c`), the cursor of a query is named by
``SQLSetCursorName`` (or ``SQLGetCursorName`` returns the name that it was
given). Another statement of the connection can change the cursor's current row
(the ``SQL_ATTR_CURRENT_OF_POSITION`` row of the rowset) with a positioned
``DELETE`` or ``UPDATE``:

.. code-block:: c

  SQLSetCursorName(stmt, (SQLCHAR *)"c", SQL_NTS);
  SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM products", SQL_NTS);
  SQLFetch(stmt);
  SQLExecDirect(stmt2, (SQLCHAR *)"DELETE FROM products WHERE CURRENT OF c",
                SQL_NTS);

The cursor must have been opened before the positioned statement is prepared
or executed. A prepared positioned statement stays prepared if the cursor is
closed and opened again, but it's destroyed with the cursor (by preparing or
executing another statement on ``stmt``, or freeing it), after which
``SQLExecute`` is a function sequence error.

The cursor is holdable unless ``SQL_ATTR_CURSOR_HOLDABLE`` is
``SQL_NONHOLDABLE``.

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

A ``SCROLL`` cursor:

.. code-block:: sql

  CREATE TABLE t (x INT);
  INSERT INTO t (x) VALUES (1), (2), (3), (4);

  START TRANSACTION;
  DECLARE c SCROLL CURSOR FOR SELECT x FROM t ORDER BY x;
  OPEN c;
  FETCH LAST FROM c;
  FETCH PRIOR FROM c;
  FETCH ABSOLUTE 1 FROM c;
  FETCH RELATIVE 2 FROM c;
  FETCH ABSOLUTE -2 FROM c;
  FETCH ABSOLUTE 5 FROM c;
  FETCH PRIOR FROM c;
  COMMIT;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 4
  -- msg: START TRANSACTION
  -- msg: DECLARE CURSOR
  -- msg: OPEN
  -- X: 4
  -- X: 3
  -- X: 1
  -- X: 3
  -- X: 3
  -- warning 02000: no data
  -- X: 4
  -- msg: COMMIT
