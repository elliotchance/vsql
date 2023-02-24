SET SCHEMA
==========

.. contents::

Syntax
------

.. code-block:: text

  SET SCHEMA <expr>

``SET SCHEMA`` changes the currently selected schema. The current schema is
where objects (such as tables, sequences, etc) are located or created.

The default schema is ``PUBLIC`` and is created automatically when the database
file is initialized.

``CURRENT_SCHEMA`` can be used in expressions to get the currently selected
schema.

Examples
--------

.. code-block:: sql

   CREATE SCHEMA foo;
   VALUES CURRENT_SCHEMA;
   SET SCHEMA 'FOO';
   VALUES CURRENT_SCHEMA;
   -- msg: CREATE SCHEMA 1
   -- COL1: PUBLIC
   -- msg: SET SCHEMA 1
   -- COL1: FOO

See Also
--------

- :doc:`create-schema`
- :doc:`drop-schema`
