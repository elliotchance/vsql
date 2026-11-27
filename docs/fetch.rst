FETCH
=====

``FETCH`` moves a cursor that was opened with :doc:`open` to another row, and
returns that row (see :doc:`cursors`).

.. contents::

Syntax
------

.. code-block:: text

  FETCH [ [ <orientation> ] FROM ] <cursor_name>

  <orientation> ::=
      NEXT
    | PRIOR
    | FIRST
    | LAST
    | ABSOLUTE <number>
    | RELATIVE <number>

The SQL standard only allows ``FETCH`` in an SQL-client module (see
:doc:`sql-client-modules`), where it puts the values of the row into
variables (with ``INTO``). Running it directly is a vsql extension, so
``FETCH`` returns the row instead of putting its values into variables. This is
flagged by ``V110-01`` (see :doc:`sql-flagging`).

Each ``FETCH`` moves to the next row and returns it. After the last row,
``FETCH`` returns no rows, with the completion condition ``02000`` (no data).

A cursor that isn't open can't be fetched (``24000``).

The rows of a cursor are found when it's opened, so a ``FETCH`` returns the row
as it was then, even if it has been changed since. A ``WITH HOLD`` cursor must
be fetched in the current transaction before its row can be changed with a
positioned :doc:`delete` or :doc:`update`.

Scrollable Cursors
------------------

A ``SCROLL`` cursor (see :doc:`declare-cursor`) can also be fetched in other
directions. A cursor that isn't ``SCROLL`` (including ``NO SCROLL``) can only
``FETCH NEXT``, any other direction is an error (``42601``).

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

The rows of a ``SCROLL`` cursor don't change while it's open, so a row that was
deleted through the cursor can be fetched again (but not changed), and a row
that was updated through the cursor is fetched with its old values.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);

  START TRANSACTION;
  DECLARE c CURSOR FOR SELECT * FROM products;
  OPEN c;
  FETCH c;
  FETCH NEXT FROM c;
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
  -- warning 02000: no data
  -- msg: CLOSE
  -- msg: COMMIT

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

See Also
--------

- :doc:`cursors`
- :doc:`declare-cursor`
- :doc:`open`
- :doc:`close`
