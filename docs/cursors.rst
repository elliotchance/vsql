Cursors
=======

A cursor reads the rows of a query one at a time, and can change (or delete)
the row that it's on.

.. contents::

Statements
----------

A cursor is used with these statements, each of which has its own page:

- :doc:`declare-cursor` names a query, and decides whether the cursor is
  ``SCROLL``, ``WITH HOLD`` and updatable.
- :doc:`open` runs the query, and the cursor is positioned before the first
  row.
- :doc:`fetch` moves the cursor to another row and returns it (see
  :ref:`fetch:Scrollable Cursors` for the directions of a ``SCROLL`` cursor).
- :doc:`close` closes the cursor, which can then be opened again.
- A positioned :doc:`delete` (``DELETE ... WHERE CURRENT OF``) deletes the row
  that the cursor is on, and a positioned :doc:`update`
  (``UPDATE ... WHERE CURRENT OF``) changes it.

The SQL standard only allows these statements in an SQL-client module (such as
a C program, see :doc:`sql-client-modules`). Running them directly is a vsql
extension (see :doc:`sql-flagging`), so ``FETCH`` returns the row instead of putting its
values into variables.

A cursor belongs to the connection. It's closed when the transaction ends, and
a statement outside of a transaction is its own transaction, so a cursor is
usually used inside of ``START TRANSACTION``. A ``WITH HOLD`` cursor stays open
after a ``COMMIT``, but not after a ``ROLLBACK``.

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

The query can end with ``FOR READ ONLY`` or ``FOR UPDATE [ OF <column_name> ,
... ]``, which is used like it is in a ``DECLARE CURSOR``. Without one, the
cursor is updatable if its query is (``SQL_ATTR_CURSOR_SCROLLABLE`` doesn't
change that). A query that isn't executed by the SQL/CLI (or an SQL-client
module) can't have one (``42601``).

The cursor must have been opened before the positioned statement is prepared
or executed. A closed cursor still exists, so a positioned statement is
``24000`` (invalid cursor state) until the cursor is destroyed. A prepared
positioned statement stays prepared if the cursor is closed and opened again,
but it's destroyed with the cursor (by preparing or executing another statement
on ``stmt``, or freeing it), after which ``SQLExecute`` is a function sequence
error.

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

See Also
--------

- :doc:`declare-cursor`
- :doc:`open`
- :doc:`fetch`
- :doc:`close`
- :doc:`delete`
- :doc:`update`
