CREATE TABLE
============

.. contents::

Syntax
------

.. code-block:: text

  CREATE TABLE <table_name> ( <element> , ... )

  <element> := <column_name> <data_type> [ DEFAULT <default> ]
               [ <column_constraint> ... ]
             | PRIMARY KEY ( <column_name> , ... )
             | CHECK ( <condition> )

  <default> := <literal>
             | CURRENT_DATE | CURRENT_TIME | CURRENT_TIMESTAMP
             | LOCALTIME | LOCALTIMESTAMP
             | CURRENT_CATALOG | CURRENT_SCHEMA
             | NULL

  <column_constraint> := NOT NULL
                       | PRIMARY KEY
                       | CHECK ( <condition> )

1. ``column_name`` must start with a letter, but can be followed by any letter,
   underscore (``_``) or digit for a maximum length of 128 characters. A
   quoted name (such as ``"order"``) can contain any characters. See
   :doc:`keywords`.
2. ``data_type`` is one of the types in :doc:`booleans`, :doc:`dates-times`,
   :doc:`numbers` and :doc:`text`.
3. A table can have up to 1600 columns.

Columns allow ``NULL`` unless they are ``NOT NULL``. ``UNIQUE`` and
``FOREIGN KEY`` constraints are not supported yet, and constraints can't be
named (with ``CONSTRAINT <name>``).

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
      name CHARACTER VARYING(100) NOT NULL
  );

  CREATE TABLE orders (
      order_id INTEGER PRIMARY KEY,
      quantity INTEGER DEFAULT 1 NOT NULL CHECK (quantity > 0),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE discounts (
      min_quantity INTEGER,
      max_quantity INTEGER,
      CHECK (min_quantity <= max_quantity)
  );

See Also
--------

- :doc:`drop-table`
- :doc:`insert`
