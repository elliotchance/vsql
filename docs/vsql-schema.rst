VSQL Schema
===========

.. contents::

Every catalog has a ``VSQL`` schema, for everything that's built into vsql
that isn't in the SQL standard. Like the ``INFORMATION_SCHEMA`` (see
:doc:`information-schema`), it's always there, and it isn't stored in the
database file or part of a dump.

The ``VSQL`` schema is read-only. Creating, changing or dropping anything in
it (or the schema itself) is a ``42501`` error, and a schema can't be created
with its name:

.. code-block:: sql

  CREATE TABLE vsql.t (x INT);
  -- error 42501: insufficient privilege: VSQL is read-only

  CREATE SCHEMA vsql;
  -- error 42P06: duplicate schema: VSQL

Views
-----

``LAST_VACUUM`` is what the last ``VACUUM`` of the connection did, and
``LAST_VACUUM_ANALYZE`` is how much space each table and index takes, from the
last ``VACUUM ANALYZE``, see :doc:`vacuum`. Their columns are named and typed
like the views of the ``INFORMATION_SCHEMA``.

Functions
---------

The functions that vsql has beyond the SQL standard, such as ``GCD``, ``NOW``
and ``SPLIT_PART``, are the routines of the ``VSQL`` schema. So are the
functions that are registered with ``register_function`` (see
:doc:`custom-functions`), and the PostgreSQL functions that a PostgreSQL
client gets (see :doc:`compatibility-postgresql`). They're described by the
``ROUTINES`` and ``PARAMETERS`` views of the ``INFORMATION_SCHEMA``, as if each
one was created as an external function in the ``VSQL`` schema.

A function can be qualified by the ``VSQL`` schema (and the catalog), or not:

.. code-block:: sql

  VALUES VSQL.GCD(12, 18);
  -- COL1: 6

  VALUES GCD(12, 18);
  -- COL1: 6

A function that isn't qualified is found by the SQL path, which always ends with
the ``VSQL`` schema. That can't be changed, so ``VSQL`` is the last place that
a function is looked for. If another schema has a function with the same name
(when vsql has ``CREATE FUNCTION``), that one is used, and ``VSQL.GCD`` is
always the built-in ``GCD``.

A function of the SQL standard, such as ``ABS`` or ``UPPER``, isn't a routine.
It's part of the SQL grammar, so it isn't in the ``VSQL`` schema (or any other
schema), and it can't be qualified. Neither can an aggregate function, such as
``PRODUCT``.
