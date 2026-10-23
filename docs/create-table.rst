CREATE TABLE
============

.. contents::

Syntax
------

.. code-block:: text

  CREATE TABLE <table_name> ( <element> , ... )

  <element> := <column_name> <data_type> [ <column_constraint> ... ]
             | PRIMARY KEY ( <column_name> , ... )

  <column_constraint> := NOT NULL
                       | PRIMARY KEY

1. ``column_name`` must start with a letter, but can be followed by any letter,
   underscore (``_``) or digit for a maximum length of 128 characters. A
   quoted name (such as ``"order"``) can contain any characters. See
   :doc:`keywords`.
2. ``data_type`` is one of the types in :doc:`booleans`, :doc:`dates-times`,
   :doc:`numbers` and :doc:`text`.

Columns allow ``NULL`` unless they are ``NOT NULL``. Column defaults, and
``UNIQUE``, ``FOREIGN KEY`` and ``CHECK`` constraints are not supported yet.

Primary Keys
------------

One or more columns can be defined in the ``PRIMARY KEY``. A column may only
appear once in the ``PRIMARY KEY`` and only integer types (``SMALLINT``,
``INTEGER`` and ``BIGINT``) are supported at the moment.

A ``PRIMARY KEY`` of a single column can also be written on the column, so
``id INTEGER PRIMARY KEY`` is the same as ``id INTEGER, PRIMARY KEY (id)``. A
table can only have one ``PRIMARY KEY``.

The ``PRIMARY KEY`` both prevents the same value from being inserted (an error
``23505``) and makes a ``WHERE`` that compares it with ``=`` fast.

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

See Also
--------

- :doc:`drop-table`
- :doc:`insert`
