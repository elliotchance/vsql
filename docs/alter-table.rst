ALTER TABLE
===========

.. contents::

Syntax
------

.. code-block:: text

  ALTER TABLE <table_name> <action>

  <action> :=
      ADD [ COLUMN ] <column_definition>
    | ALTER [ COLUMN ] <column_name> SET DEFAULT <default>
    | ALTER [ COLUMN ] <column_name> DROP DEFAULT
    | ALTER [ COLUMN ] <column_name> RESTART [ WITH <value> ]
    | DROP [ COLUMN ] <column_name> [ CASCADE | RESTRICT ]
    | ADD [ CONSTRAINT <constraint_name> ] <table_constraint>
    | DROP CONSTRAINT <constraint_name> [ CASCADE | RESTRICT ]

  <column_definition> := <column_name> <data_type> [ DEFAULT <default> ]
                         [ [ CONSTRAINT <constraint_name> ] <column_constraint> ... ]

ADD COLUMN
----------

Adds a column to a table, after its other columns. The column is defined the
same way as a column of a :doc:`create-table`, with the same rules for its
name, ``DEFAULT`` and constraints.

Every existing row gets the ``DEFAULT`` of the new column, which is ``NULL``
if the column doesn't have one. A default such as ``CURRENT_TIMESTAMP`` is
evaluated once, so all of the existing rows get the same value.
An identity column (see :doc:`create-table`) can't be added yet, it's an error
``0A000``.

The existing rows must satisfy the constraints of the new column, otherwise the
column isn't added:

- A ``NOT NULL`` column without a ``DEFAULT`` (an error ``23502``) can only be
  added to an empty table.
- A ``CHECK`` that's ``FALSE`` for the default is an error ``23514``, unless
  the table is empty.
- A column can only be the ``PRIMARY KEY`` if the table doesn't have one yet
  (an error ``42601``). Every existing row gets the same default, so it's an
  error ``23505`` if there's more than one row.
- A ``UNIQUE`` column with a ``DEFAULT`` (that isn't ``NULL``) is an error
  ``23505`` if there's more than one row, for the same reason.
- A ``REFERENCES`` column with a ``DEFAULT`` (that isn't ``NULL``) is an
  error ``23503`` if the default doesn't reference a row, unless the table is
  empty.

ALTER COLUMN
------------

``SET DEFAULT`` sets (or replaces) the ``DEFAULT`` of a column. It's checked
the same way as the ``DEFAULT`` of a column of a :doc:`create-table`, such as
``DEFAULT 'x'`` not being valid for an ``INTEGER`` (an error ``42601``).

``DROP DEFAULT`` removes the ``DEFAULT`` of a column, so its default is
``NULL``. It's an error ``42601`` if the column doesn't have a ``DEFAULT``,
although ``DEFAULT NULL`` can be dropped.

``RESTART`` changes the next value of an identity column (see
:doc:`create-table`), the same way as :doc:`alter-sequence`. Without a value it
starts again from the ``START WITH``. The ``DEFAULT`` of an identity column
can't be changed, and ``RESTART`` can only be used for an identity column (both
are an error ``42601``).

Only the definition of the table is changed. The existing rows keep their
values, and the new default is used by the rows that are inserted after it.
Changing the type of a column, or whether it's ``NOT NULL``, isn't supported
yet.

DROP COLUMN
-----------

Drops a column of a table, along with its value in every row. The columns after
it move up one position. A table must have at least one column, so the only
column can't be dropped (an error ``42601``). It's an error ``42703`` if the
column doesn't exist.

The constraints that only use the column are dropped with it: its
``NOT NULL``, a ``CHECK`` that only uses the column, and a ``PRIMARY KEY`` or
``UNIQUE`` of only that column. Any other constraint that uses the column can
only be dropped with ``CASCADE``, which drops it too. Otherwise, it's an error
``2BP01``. ``RESTRICT`` is used when neither is given. These constraints are:

- A ``PRIMARY KEY`` or ``UNIQUE`` of more than one column. The ``NOT NULL`` of
  the other columns of a ``PRIMARY KEY`` isn't dropped.
- A ``CHECK`` that also uses other columns.
- A ``FOREIGN KEY`` of the table with the column as one of its columns, or a
  ``FOREIGN KEY`` (of any table) that references the column, because it also
  uses the columns of the other table. A ``FOREIGN KEY`` that only references
  the same column of the same table is dropped with the column.

Every row of the table is written again, because the values of a row are
stored in the order of its columns. The rows are also moved when the
``PRIMARY KEY`` is dropped.

ADD CONSTRAINT
--------------

Adds a ``PRIMARY KEY``, ``UNIQUE``, ``FOREIGN KEY`` or ``CHECK`` constraint
to a table. It's defined the same way as a constraint of a
:doc:`create-table`, with the same rules (such as a table only having one
``PRIMARY KEY``), and gets a name in the same way if it isn't given one
(see "Constraint Names" in :doc:`create-table`).

Every existing row must satisfy the new constraint, otherwise it isn't added:
an error ``23514`` for a ``CHECK``, ``23505`` for a ``PRIMARY KEY`` or
``UNIQUE``, or ``23503`` for a ``FOREIGN KEY``. The columns of a new
``PRIMARY KEY`` become ``NOT NULL``, so it's an error ``23502`` if any of them
are ``NULL``. Every row of the table is read to check the constraint, and the
rows are rewritten for a new ``PRIMARY KEY``, because they're stored by it.

DROP CONSTRAINT
---------------

Drops a constraint of the table, which can be any of its constraints,
including a ``NOT NULL``. It's an error ``42704`` if the table doesn't have a
constraint with that name. The other constraints keep their names.

A ``PRIMARY KEY`` or ``UNIQUE`` that's referenced by a ``FOREIGN KEY`` (of any
table, including itself) can only be dropped with ``CASCADE``, which also drops
the ``FOREIGN KEY``. Otherwise, it's an error ``2BP01``. ``RESTRICT`` is used
when neither is given.

The ``NOT NULL`` of a column in the ``PRIMARY KEY`` can't be dropped (an
error ``42601``). Dropping the ``PRIMARY KEY`` doesn't drop the ``NOT NULL`` of
its columns, which can be dropped separately. The rows are rewritten when the
``PRIMARY KEY`` is dropped, because they're stored by it.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50));
  INSERT INTO products (name) VALUES ('Bread');
  ALTER TABLE products ADD COLUMN price NUMERIC(10, 2);
  ALTER TABLE products ADD COLUMN quantity INTEGER DEFAULT 1 NOT NULL;
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: ALTER TABLE 1
  -- msg: ALTER TABLE 1
  -- NAME: Bread PRICE: NULL QUANTITY: 1

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), quantity INTEGER);
  INSERT INTO products (name) VALUES ('Bread');
  ALTER TABLE products ALTER COLUMN quantity SET DEFAULT 1;
  INSERT INTO products (name) VALUES ('Milk');
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: ALTER TABLE 1
  -- msg: INSERT 1
  -- NAME: Bread QUANTITY: NULL
  -- NAME: Milk QUANTITY: 1

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price INTEGER);
  INSERT INTO products (name, price) VALUES ('Bread', 3);
  ALTER TABLE products ADD CONSTRAINT positive_price CHECK (price > 0);
  INSERT INTO products (name, price) VALUES ('Milk', -1);
  ALTER TABLE products DROP CONSTRAINT positive_price;
  INSERT INTO products (name, price) VALUES ('Milk', -1);
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: ALTER TABLE 1
  -- error 23514: violates check constraint: CHECK (PRICE > 0) on ":memory:".PUBLIC.PRODUCTS
  -- msg: ALTER TABLE 1
  -- msg: INSERT 1

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price INTEGER CHECK (price > 0));
  INSERT INTO products (name, price) VALUES ('Bread', 3);
  ALTER TABLE products DROP COLUMN price;
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: ALTER TABLE 1
  -- NAME: Bread

See Also
--------

- :doc:`create-table`
- :doc:`drop-table`
