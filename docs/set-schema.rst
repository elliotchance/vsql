SET SCHEMA
==========

.. contents::

Syntax
------

.. code-block:: text

  SET SCHEMA <expr>

``SET SCHEMA`` changes the currently selected schema. The current schema is
where objects (such as tables, sequences, etc) are located or created.

The value is a character string that contains the name of the schema as an
identifier, so ``SET SCHEMA 'foo'`` selects the schema ``FOO`` (the same as a
table named ``foo`` is ``FOO``). Put double quotes inside the string for a name
that isn't upper case, such as ``SET SCHEMA '"foo"'`` for a schema created with
``CREATE SCHEMA "foo"``. A value that isn't an identifier is a ``3F000``
(invalid schema name) error.

The default schema is ``PUBLIC`` and is created automatically when the database
file is initialized.

``CURRENT_SCHEMA`` can be used in expressions to get the currently selected
schema.

Examples
--------

.. code-block:: sql

   CREATE SCHEMA foo;
   VALUES CURRENT_SCHEMA;
   SET SCHEMA 'foo';
   VALUES CURRENT_SCHEMA;
   -- msg: CREATE SCHEMA 1
   -- COL1: PUBLIC
   -- msg: SET SCHEMA 1
   -- COL1: FOO

See Also
--------

- :doc:`create-schema`
- :doc:`drop-schema`
