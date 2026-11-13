DROP SCHEMA
===========

.. contents::

Syntax
------

.. code-block:: text

  DROP SCHEMA [ IF EXISTS ] <schema_name> { CASCADE | RESTRICT }

Drop (delete) a schema.

If ``RESTRICT`` is specified and the schema is not empty, an error will be
returned and no action will be taken.

If ``CASCADE`` is specified then the schema is dropped, including any objects
within it. A ``FOREIGN KEY`` of a table in another schema that
references one of its tables is also dropped (see :doc:`drop-table`), and so is
a view in another schema that reads one of its tables or views (see
:doc:`drop-view`).

One of ``CASCADE`` or ``RESTRICT`` must be provided.

With ``IF EXISTS``, a schema that doesn't exist isn't an error. Nothing changes,
and the result is ``DROP SCHEMA 0``. A catalog that doesn't exist is still an
error. If the schema exists, it's the same as ``DROP SCHEMA``, including
``CASCADE``, ``RESTRICT`` and their errors, so one of them is still required.

``IF EXISTS`` is a vsql extension, not standard SQL. It's flagged as ``V102-01``
(see :doc:`sql-flagging`).

Examples
--------

.. code-block:: sql

  DROP SCHEMA warehouse CASCADE;

See Also
--------

- :doc:`create-schema`
