CREATE SCHEMA
=============

.. contents::

Syntax
------

.. code-block:: text

  CREATE SCHEMA <schema_name> [ <schema_element> ... ]

  <schema_element> ::=
      <create_table>
    | <create_sequence>

A schema is a container for other objects such as tables.

Each ``CREATE TABLE`` (see :doc:`create-table`) and ``CREATE SEQUENCE`` (see
:doc:`create-sequence`) is created in the new schema, in the order they're
written, so a ``FOREIGN KEY`` can only reference a table that's before it. An
unqualified name in them is in the new schema, whatever the current schema is. If
one of them fails, the schema isn't created.

The names of objects only need to be unique within a single schema and referring
to an object in a particular schema is done by prepending the schema name
followed by a period (see examples).

Every catalog already has an ``INFORMATION_SCHEMA`` schema (see
:doc:`information-schema`), so it can't be created.

Examples
--------

.. code-block:: sql

  CREATE SCHEMA warehouse;

  CREATE TABLE warehouse.products (
      title CHARACTER VARYING(100),
      price FLOAT
  );

  SELECT * FROM warehouse.products;

  CREATE SCHEMA store
    CREATE TABLE customers (id INT PRIMARY KEY)
    CREATE TABLE orders (customer_id INT REFERENCES customers);

See Also
--------

- :doc:`drop-schema`
