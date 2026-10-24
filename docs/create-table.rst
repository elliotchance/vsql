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

  <default> := <literal>
             | CURRENT_DATE | CURRENT_TIME | CURRENT_TIMESTAMP
             | LOCALTIME | LOCALTIMESTAMP
             | CURRENT_CATALOG | CURRENT_SCHEMA
             | NULL

  <column_constraint> := NOT NULL
                       | PRIMARY KEY

1. ``column_name`` must start with a letter, but can be followed by any letter,
   underscore (``_``) or digit for a maximum length of 128 characters. A
   quoted name (such as ``"order"``) can contain any characters. See
   :doc:`keywords`.
2. ``data_type`` is one of the types in :doc:`booleans`, :doc:`dates-times`,
   :doc:`numbers` and :doc:`text`.
3. A table can have up to 1600 columns.

Columns allow ``NULL`` unless they are ``NOT NULL``. ``UNIQUE``,
``FOREIGN KEY`` and ``CHECK`` constraints are not supported yet.

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
      quantity INTEGER DEFAULT 1 NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
  );

See Also
--------

- :doc:`drop-table`
- :doc:`insert`
