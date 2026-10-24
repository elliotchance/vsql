CREATE SCHEMA
=============

.. contents::

Syntax
------

.. code-block:: text

  CREATE SCHEMA <schema_name>

A schema is a container for other objects such as tables.

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

See Also
--------

- :doc:`drop-schema`
