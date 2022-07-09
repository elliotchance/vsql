DROP SCHEMA
===========

.. contents::

Syntax
------

.. code-block:: text

  DROP SCHEMA <schema_name> { CASCADE | RESTRICT }

Drop (delete) a schema.

If ``RESTRICT`` is specified and the schema is not empty, an error will be
returned and no action will be taken.

If ``CASCADE`` is specified then schema is dropped including any objects within
it.

Examples
--------

.. code-block:: sql

  DROP SCHEMA warehouse;

See Also
--------

- :doc:`create-schema`
