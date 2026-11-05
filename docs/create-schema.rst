CREATE SCHEMA
=============

.. contents::

Syntax
------

.. code-block:: text

  CREATE SCHEMA [ IF NOT EXISTS ] <schema_name> [ <schema_element> ... ]

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

IF NOT EXISTS
-------------

With ``IF NOT EXISTS``, a schema that already exists (including
``INFORMATION_SCHEMA``) isn't an error. Nothing changes (including the
``CREATE TABLE`` and ``CREATE SEQUENCE`` in the statement, which aren't created),
and the result is ``CREATE SCHEMA 0``. If the schema doesn't exist, it's the same as
``CREATE SCHEMA``, so the result is ``CREATE SCHEMA 1``.

``IF NOT EXISTS`` is a vsql extension, not standard SQL. It's flagged as
``V101-01`` (see :doc:`sql-flagging`).

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
