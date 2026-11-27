CLOSE
=====

``CLOSE`` closes a cursor that was opened with :doc:`open` (see
:doc:`cursors`).

.. contents::

Syntax
------

.. code-block:: text

  CLOSE <cursor_name>

The SQL standard only allows ``CLOSE`` in an SQL-client module (such as a C
program, see :doc:`language-c`). Running it directly is a vsql extension,
flagged by ``V111-01`` (see :doc:`sql-flagging`).

``CLOSE`` closes the cursor, which can then be opened again. The cursor stays
declared (see :doc:`declare-cursor`). A cursor that isn't open can't be closed
(``24000``).

A cursor is also closed when the transaction ends, unless it's ``WITH HOLD``
and the transaction is committed. A ``WITH HOLD`` cursor is still closed by a
``ROLLBACK``.

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
  -- msg: OPEN
  -- NAME: Coffee PRICE: 4.50
  -- msg: CLOSE
  -- msg: COMMIT

See Also
--------

- :doc:`cursors`
- :doc:`declare-cursor`
- :doc:`open`
- :doc:`fetch`
