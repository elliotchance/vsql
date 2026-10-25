CREATE TABLE
============

.. contents::

Syntax
------

.. code-block:: text

  CREATE TABLE <table_name> ( <element> , ... )

  <element> := <column_name> <data_type> [ DEFAULT <default> ]
               [ [ CONSTRAINT <constraint_name> ] <column_constraint>
                 [ <characteristics> ] ... ]
             | [ CONSTRAINT <constraint_name> ] <table_constraint>
               [ <characteristics> ]

  <table_constraint> := PRIMARY KEY ( <column_name> , ... )
                      | UNIQUE ( <column_name> , ... )
                      | FOREIGN KEY ( <column_name> , ... ) <references>
                      | CHECK ( <condition> )

  <default> := <literal>
             | CURRENT_DATE | CURRENT_TIME | CURRENT_TIMESTAMP
             | LOCALTIME | LOCALTIMESTAMP
             | CURRENT_CATALOG | CURRENT_SCHEMA
             | NULL

  <column_constraint> := NOT NULL
                       | PRIMARY KEY
                       | UNIQUE
                       | <references>
                       | CHECK ( <condition> )

  <references> := REFERENCES <table_name> [ ( <column_name> , ... ) ]
                  [ ON UPDATE <referential_action> ]
                  [ ON DELETE <referential_action> ]

  <referential_action> := CASCADE | SET NULL | SET DEFAULT | NO ACTION

  <characteristics> := [ NOT ] DEFERRABLE [ INITIALLY { DEFERRED | IMMEDIATE } ]
                     | INITIALLY { DEFERRED | IMMEDIATE } [ [ NOT ] DEFERRABLE ]

1. ``column_name`` must start with a letter, but can be followed by any letter,
   underscore (``_``) or digit for a maximum length of 128 characters. A
   quoted name (such as ``"order"``) can contain any characters. See
   :doc:`keywords`.
2. ``data_type`` is one of the types in :doc:`booleans`, :doc:`dates-times`,
   :doc:`numbers` and :doc:`text`.
3. A table can have up to 1600 columns.

Columns allow ``NULL`` unless they are ``NOT NULL``.

Defaults
--------

A column's ``DEFAULT`` is used when the column isn't listed in an
:doc:`insert`, or when the value is ``DEFAULT`` in an :doc:`insert` or
:doc:`update`. A column without a ``DEFAULT`` has a default of ``NULL``. The
``DEFAULT`` must be before any constraints, such as
``id INTEGER DEFAULT 0 NOT NULL``.

The default is a literal, a datetime function (which is evaluated each time the
default is used), ``CURRENT_CATALOG``, ``CURRENT_SCHEMA`` or ``NULL``. It can't
be an expression, such as ``1 + 2``.

The default must suit the type of the column, otherwise it's an error
``42601``:

- The default must be the same kind of value as the column (a number, text, a
  boolean, or a date or time). It's not converted, so ``DEFAULT '12'`` isn't
  allowed for a number column.
- A text default can't be longer than the column.
- An exact number column (such as ``INTEGER`` or ``NUMERIC``) can't have an
  approximate default (such as ``1e2``), or a default that would lose any
  digits, such as ``1.5`` for an ``INTEGER`` or ``100000`` for a ``SMALLINT``.
- A date or time column must have a default with the same fields (``DATE``,
  ``TIME`` or ``TIMESTAMP``). A column ``WITH TIME ZONE`` can't have a literal
  default without a time zone.
- ``CURRENT_CATALOG`` and ``CURRENT_SCHEMA`` are only for text columns.

Primary Keys
------------

One or more columns, of any type, can be defined in the ``PRIMARY KEY``. A
column may only appear once in the ``PRIMARY KEY``.

A ``PRIMARY KEY`` of a single column can also be written on the column, so
``id INTEGER PRIMARY KEY`` is the same as ``id INTEGER, PRIMARY KEY (id)``. A
table can only have one ``PRIMARY KEY``.

The ``PRIMARY KEY`` prevents the same value from being inserted (an error
``23505``). Values that are equal are the same, such as ``1.5`` and ``1.50``,
``'a'`` and ``'a '``, or two times with a time zone that are the same in UTC.
For a ``PRIMARY KEY`` of one integer column, a ``WHERE`` that compares it with
``=`` is also fast.

A ``PRIMARY KEY`` does not allow ``NULL``, so all columns used in the
``PRIMARY KEY`` are ``NOT NULL``, even if they are not declared that way.

Unique Constraints
------------------

A ``UNIQUE`` constraint prevents two rows from having the same values for its
columns (an error ``23505``), like a ``PRIMARY KEY``. Values that are equal are
the same in the same way. A row with a ``NULL`` in any of the columns never
conflicts, so a ``UNIQUE`` column can have any number of ``NULL`` values.

A ``UNIQUE`` of a single column can also be written on the column, so
``code INTEGER UNIQUE`` is the same as ``code INTEGER, UNIQUE (code)``. A table
can have any number of ``UNIQUE`` constraints, but each one (and the
``PRIMARY KEY``) must have a different set of columns. A column may only appear
once in each ``UNIQUE``.

The constraints are checked once all of the rows of an :doc:`insert` or
:doc:`update` have been changed, so ``UPDATE t SET code = code + 1`` works. If
any row conflicts, none of the rows are changed. Every row of the table is read
to check the constraints, because there are no indexes yet.

Foreign Keys
------------

A ``FOREIGN KEY`` constraint (also called a referential constraint) means that
each row must reference a row of another table, the referenced table. The
values of its columns must be the same as the values of the referenced columns
of a row of the referenced table, otherwise it's an error ``23503``. A row with
a ``NULL`` in any of the columns doesn't need to reference a row.

.. code-block:: sql

  CREATE TABLE categories (category_id INTEGER PRIMARY KEY);
  CREATE TABLE products (
      product_id INTEGER PRIMARY KEY,
      category_id INTEGER REFERENCES categories
  );
  INSERT INTO categories (category_id) VALUES (1);
  INSERT INTO products (product_id, category_id) VALUES (1, 1);
  INSERT INTO products (product_id, category_id) VALUES (2, 2);
  -- msg: CREATE TABLE 1
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: INSERT 1
  -- error 23503: violates foreign key constraint: FOREIGN KEY (CATEGORY_ID) REFERENCES ":memory:".PUBLIC.CATEGORIES (CATEGORY_ID) on ":memory:".PUBLIC.PRODUCTS

A ``FOREIGN KEY`` of a single column can also be written on the column, so
``category_id INTEGER REFERENCES categories`` is the same as
``category_id INTEGER, FOREIGN KEY (category_id) REFERENCES categories``. A
table can have any number of ``FOREIGN KEY`` constraints.

The referenced columns are the ``PRIMARY KEY`` of the referenced table, unless
they're listed after the table name. Listed columns must be the columns of the
``PRIMARY KEY`` or a ``UNIQUE`` constraint of the referenced table, in any
order. Each column of the ``FOREIGN KEY`` corresponds to the referenced column
in the same position, so ``FOREIGN KEY (a, b) REFERENCES t (x, y)`` means that
``a`` must be the same as ``x``, and ``b`` the same as ``y``. Otherwise, it's an
error ``42830``. The types of the corresponding columns must be compatible (an
error ``42804``): both are integers (``SMALLINT``, ``INTEGER`` or ``BIGINT``),
``REAL`` or ``DOUBLE PRECISION``, ``NUMERIC`` or ``DECIMAL``, ``CHARACTER`` or
``CHARACTER VARYING``, or both are the same type for any other type. The values
are compared like a ``PRIMARY KEY``.

The referenced table must already exist and be in the same catalog, but it can
be the table that's being created (such as an ``employees`` table where each
employee references their manager).

A row that's referenced can't be deleted, and its referenced columns can't be
changed, otherwise it's an error ``23503``. A ``FOREIGN KEY`` is checked once
all of the rows of an :doc:`insert`, :doc:`update` or :doc:`delete` have been
changed, so a statement can delete a row along with the rows that reference
it, or insert a row along with a row that references it. If any row violates
the constraint, none of the rows are changed. ``MATCH`` is not supported yet.

``ON DELETE`` says what happens to the rows that reference a row that's
deleted, and ``ON UPDATE`` says what happens to the rows that reference a row
when its referenced columns are changed by an :doc:`update`. They can be given
in either order:

- ``NO ACTION`` (the default) is the error ``23503`` described above.
- ``CASCADE`` deletes the rows that reference it (``ON DELETE``), or changes
  their columns of the ``FOREIGN KEY`` to the new values of the referenced
  columns (``ON UPDATE``). Those rows can be referenced by other rows, so this
  can delete or change their rows, and so on.
- ``SET NULL`` sets each column of the ``FOREIGN KEY`` to ``NULL`` in the rows
  that reference it.
- ``SET DEFAULT`` sets each column of the ``FOREIGN KEY`` to its ``DEFAULT``
  (or ``NULL`` when there isn't one) in the rows that reference it.

.. code-block:: sql

  CREATE TABLE orders (order_id INTEGER PRIMARY KEY);
  CREATE TABLE order_lines (
      order_id INTEGER REFERENCES orders ON DELETE CASCADE,
      line_number INTEGER
  );
  INSERT INTO orders (order_id) VALUES (1), (2);
  INSERT INTO order_lines (order_id, line_number) VALUES (1, 1), (1, 2), (2, 1);

  DELETE FROM orders WHERE order_id = 1;
  SELECT * FROM order_lines;
  -- ORDER_ID: 2 LINE_NUMBER: 1

  CREATE TABLE customers (customer_code VARCHAR(10) PRIMARY KEY);
  CREATE TABLE invoices (
      invoice_id INTEGER PRIMARY KEY,
      customer_code VARCHAR(10) REFERENCES customers ON UPDATE CASCADE
  );
  INSERT INTO customers (customer_code) VALUES ('ACME');
  INSERT INTO invoices (invoice_id, customer_code) VALUES (1, 'ACME');

  UPDATE customers SET customer_code = 'ACME2';
  SELECT * FROM invoices;
  -- INVOICE_ID: 1 CUSTOMER_CODE: ACME2

A row that's changed by ``SET NULL`` or ``SET DEFAULT`` must still satisfy
every constraint of its table, including the ``FOREIGN KEY`` itself, so
``SET DEFAULT`` is an error ``23503`` if the default doesn't reference a row.
The same is true for a row that's changed by ``ON UPDATE CASCADE``. These
changes are part of the :doc:`delete` or :doc:`update`, so if any of them fail,
no rows are deleted or changed.

A table that's referenced can only be dropped with ``CASCADE``, which also
drops the ``FOREIGN KEY`` constraints that reference it (see :doc:`drop-table`).

Every row of the referenced table is read to check the new rows of a
statement, and every row of each table that references a table is read when
its rows are deleted or updated, because there are no indexes yet.

Check Constraints
-----------------

A ``CHECK`` constraint is a condition that every row of the table must satisfy.
It's checked for each row of an :doc:`insert` or :doc:`update`, after the
values are converted to the types of the columns (and defaults are used). A row
that makes the condition ``FALSE`` is an error ``23514``, and none of the rows
of the statement are changed. The condition is only violated when it's
``FALSE``, so ``CHECK (price > 0)`` allows a ``NULL`` price. Add ``NOT NULL``
to prevent that.

A ``CHECK`` on the table can use any of the columns of the table, such as
``CHECK (low <= high)``. A ``CHECK`` on a column can only use that column. A
table can have any number of ``CHECK`` constraints, and they are checked in the
order they're defined.

The condition must always give the same result for the same row, so it can't
contain (an error ``42601``):

- An aggregate function (such as ``COUNT(*)``), ``NEXT VALUE FOR`` or a
  parameter.
- ``CURRENT_DATE``, ``CURRENT_TIME``, ``CURRENT_TIMESTAMP``, ``LOCALTIME``,
  ``LOCALTIMESTAMP``, ``CURRENT_CATALOG`` or ``CURRENT_SCHEMA``.
- A :doc:`custom function <custom-functions>`.
- Anything that depends on the time zone of the session: comparing a date or
  time without a time zone with one that has a time zone, a ``CAST`` to a type
  ``WITH TIME ZONE`` from one without a time zone, or a ``CAST`` from a
  ``TIME`` to a ``TIMESTAMP`` (which uses ``CURRENT_DATE``).

A condition that isn't a ``BOOLEAN`` is an error ``42804``.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (
      product_id INTEGER NOT NULL,
      title CHARACTER VARYING(100),
      price NUMERIC(10, 2),
      PRIMARY KEY (product_id)
  );

  CREATE TABLE categories (
      category_id INTEGER PRIMARY KEY,
      name CHARACTER VARYING(100) NOT NULL UNIQUE
  );

  CREATE TABLE orders (
      order_id INTEGER PRIMARY KEY,
      product_id INTEGER NOT NULL REFERENCES products,
      quantity INTEGER DEFAULT 1 NOT NULL CHECK (quantity > 0),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE discounts (
      min_quantity INTEGER,
      max_quantity INTEGER,
      CHECK (min_quantity <= max_quantity)
  );

Constraint Names
----------------

Every constraint has a name, which is used to drop it (see :doc:`alter-table`)
and is in the :doc:`information-schema`. A constraint is named with
``CONSTRAINT <constraint_name>`` before it, on a column or the table:

.. code-block:: sql

  CREATE TABLE products (
      id INTEGER CONSTRAINT products_pk PRIMARY KEY,
      price INTEGER CONSTRAINT price_not_null NOT NULL,
      CONSTRAINT positive_price CHECK (price > 0)
  );

A constraint without a name gets one from its table: ``<table>_PRIMARY_KEY``
for the ``PRIMARY KEY``, ``<table>_NOT_NULL_<n>`` for the ``NOT NULL`` of the
nth column, and ``<table>_UNIQUE_<n>``, ``<table>_FOREIGN_KEY_<n>`` or
``<table>_CHECK_<n>`` for the other kinds, where ``n`` is the first number
(counting from 1) that gives a name that isn't already used in the schema. For
example, the ``CHECK`` constraints of ``CREATE TABLE t (a INT CHECK (a > 0),
b INT CHECK (b > 0))`` are ``T_CHECK_1`` and ``T_CHECK_2``. A ``NOT NULL``
counts from the position of its column, and a second ``PRIMARY KEY`` name is
``<table>_PRIMARY_KEY_2``. A constraint keeps its name when other constraints
are added or dropped, and a constraint that's added after another is dropped
can get the name of the dropped constraint.

The names of the constraints must be unique in the schema (an error
``42710``), but the same name can be used in different schemas. A name can be
qualified by the schema of the table, such as ``CONSTRAINT s.positive_price``,
but not by another schema (an error ``42601``). A column can only have one named
``NOT NULL``.

Deferrable Constraints
----------------------

A constraint is checked at the end of each statement that changes a table,
unless it's ``DEFERRABLE`` and deferred. Then it's only checked at the
``COMMIT`` (see :doc:`commit`), or when :doc:`set-constraints` makes it
immediate again, so that a transaction can break it for a while, such as to
insert a row before the row that it references.

- ``INITIALLY DEFERRED`` constraints are deferred at the start of each
  transaction, and are also ``DEFERRABLE``.
- ``DEFERRABLE`` (or ``DEFERRABLE INITIALLY IMMEDIATE``) constraints are
  checked immediately, unless they're deferred with :doc:`set-constraints`.
- ``NOT DEFERRABLE`` (or ``INITIALLY IMMEDIATE``, or nothing) constraints are
  always checked immediately.

Outside of a transaction, each statement is its own transaction, so a deferred
constraint is still checked when the statement finishes. A ``UNIQUE``,
``FOREIGN KEY`` or ``CHECK`` can be deferred, but a ``PRIMARY KEY`` or ``NOT
NULL`` can't (an error ``0A000``). The referential actions of a ``FOREIGN KEY``
(such as ``ON DELETE CASCADE``) are never deferred.

A deferred constraint is checked against every row of its table, rather than
just the rows that were changed. ``NOT ENFORCED`` is not supported.

.. code-block:: sql

  CREATE TABLE parent (id INT PRIMARY KEY);
  CREATE TABLE child (
    parent_id INT REFERENCES parent INITIALLY DEFERRED
  );

  START TRANSACTION;
  INSERT INTO child (parent_id) VALUES (1);
  INSERT INTO parent (id) VALUES (1);
  COMMIT;

See Also
--------

- :doc:`alter-table`
- :doc:`drop-table`
- :doc:`insert`
- :doc:`set-constraints`
