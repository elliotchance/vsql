CREATE TABLE
============

.. contents::

Syntax
------

.. code-block:: txt

  CREATE TABLE <table_name> ( <column> , ... )

  column := <column_name> <column_type> [ NULL | NOT NULL ]

1. ``column_name`` must start with a letter, but can be followed by any letter,
underscore (``_``) or digit for a maximum length of 128 characters.
2. ``column_type`` must be one of the
`Data Types <https://github.com/elliotchance/vsql/blob/main/docs/data-types.rst>`_.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (
      title CHARACTER VARYING(100),
      price FLOAT
  );
