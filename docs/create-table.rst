CREATE TABLE
============

.. contents::

Syntax
------

.. code-block:: text

  CREATE TABLE <table_name> ( <element> , ... )

  <element> := <column_name> <column_type> [ NULL | NOT NULL ]
             | PRIMARY KEY ( <column_name> , ... )

1. ``column_name`` must start with a letter, but can be followed by any letter,
   underscore (``_``) or digit for a maximum length of 128 characters.
2. ``column_type`` must be a data type.

Primary Keys
------------

One or more columns can be defined in the PRIMARY KEY. A column may only appear
once in the PRIMARY KEY and only integer types are supported at the moment.

The PRIMARY KEY both prevents the same value from being inserted and dictates
the order that data will naturally be retreived in (even if the PRIMARY KEY is
not used).

A PRIMARY KEY does not allow NULLs, so all columns used in the PRIMARY KEY must
also be declared as ``NOT NULL``.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (
      title CHARACTER VARYING(100),
      price FLOAT
  );
