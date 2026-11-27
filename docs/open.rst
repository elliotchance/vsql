OPEN
====

``OPEN`` runs the query of a cursor that was declared with
:doc:`declare-cursor`, so that its rows can be read with :doc:`fetch` (see
:doc:`cursors`).

.. contents::

Syntax
------

.. code-block:: text

  OPEN <cursor_name>

The SQL standard only allows ``OPEN`` in an SQL-client module (such as a C
program, see :doc:`language-c`). Running it directly is a vsql extension,
flagged by ``V109-01`` (see :doc:`sql-flagging`).

``OPEN`` runs the query, and the cursor is positioned before the first row. The
rows of a cursor are found when it's opened, so a ``FETCH`` returns the row as
it was then, even if it has been changed since.

A cursor that's already open can't be opened (``24000``). A cursor that was
closed (see :doc:`close`) can be opened again.

A cursor is closed when the transaction ends (unless it's ``WITH HOLD`` and the
transaction is committed), so a cursor is usually opened inside of
``START TRANSACTION`` (see :doc:`start-transaction`).

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);

  START TRANSACTION;
  DECLARE c CURSOR FOR SELECT * FROM products;
  OPEN c;
  FETCH c;
  FETCH c;
  CLOSE c;
  COMMIT;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: START TRANSACTION
  -- msg: DECLARE CURSOR
  -- msg: OPEN
  -- NAME: Coffee PRICE: 4.50
  -- NAME: Bagel PRICE: 2.25
  -- msg: CLOSE
  -- msg: COMMIT

See Also
--------

- :doc:`cursors`
- :doc:`declare-cursor`
- :doc:`fetch`
- :doc:`close`
