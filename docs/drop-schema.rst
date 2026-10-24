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

If ``CASCADE`` is specified then the schema is dropped, including any objects
within it. A ``FOREIGN KEY`` of a table in another schema that
references one of its tables is also dropped (see :doc:`drop-table`).

One of ``CASCADE`` or ``RESTRICT`` must be provided.

Examples
--------

.. code-block:: sql

  DROP SCHEMA warehouse CASCADE;

See Also
--------

- :doc:`create-schema`
