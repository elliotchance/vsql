Catalogs and Schemas
====================

.. contents::

Tables, views and sequences are kept in schemas, and schemas are kept in
catalogs. So the full name of a table has three parts: the catalog, the schema
and the table, such as ``"archive".public.orders``.

Catalogs
--------

A catalog is a database file. A connection starts with the catalog of the file
that it opened, and more files can be attached to it as other catalogs. Then a
statement can use the tables of every file, and a transaction can change all of
them.

The name of a catalog is the base name of its file, up to the first ``.``. So
the catalog of ``/tmp/mydb.cool.vsql`` is ``mydb``. The catalog of an in-memory
database (see :doc:`in-memory-database`) is ``:memory:``.

More files are attached:

- With ``vsql cli`` or ``vsql app``, by passing more than one file (see
  :doc:`cli`). The first file is the current catalog:

  .. code-block:: text

     $ vsql cli main.vsql archive.vsql

- In V, with ``Connection.add_catalog()``, which names the catalog itself (see
  :ref:`language-v:Catalogs`):

  .. code-block:: v

     mut db := vsql.open('main.vsql')!
     db.add_catalog('archive', 'archive.vsql', vsql.default_connection_options())!

Two catalogs can't have the same name, so ``vsql cli main.vsql other/main.vsql``
fails with ``duplicate catalog: main``. ``vsql server`` only serves one file.

Schemas
-------

Each catalog has its own schemas. Every catalog starts with a ``PUBLIC`` schema,
which is the default, and also has the read-only ``INFORMATION_SCHEMA`` (see
:doc:`information-schema`) and ``VSQL`` (see :doc:`vsql-schema`) schemas. More
schemas are created with :doc:`create-schema`.

Names
-----

The examples on this page use two files, opened with ``vsql cli main.vsql
archive.vsql``. ``main.vsql`` has the customers, and ``archive.vsql`` has their
orders.

A name without a schema is in the current schema, and a name without a catalog
is in the current catalog. So, with ``main.vsql`` opened, ``customers``,
``public.customers`` and ``"main".public.customers`` are all the same table.

The names of catalogs are identifiers like any other name, so they're upper case
unless they're in double quotes (see :doc:`identifiers`). Since a catalog is
usually named after a file with a lower case name, it needs double quotes:

.. code-block:: sql

  SELECT * FROM archive.public.orders;
  -- error 3D000: invalid catalog name: ARCHIVE

A catalog that doesn't exist is a ``3D000`` error.

The current catalog and schema are changed with :doc:`set-catalog` and
:doc:`set-schema`, and are returned by ``CURRENT_CATALOG`` and
``CURRENT_SCHEMA``:

.. code-block:: sql

  VALUES ROW(CURRENT_CATALOG, CURRENT_SCHEMA);
  -- COL1: main COL2: PUBLIC

  SET CATALOG 'archive';
  SELECT * FROM orders WHERE id = 12;
  -- ID: 12 CUSTOMER_ID: 2 TOTAL: 15

  SELECT name FROM "main".public.customers WHERE id = 1;
  -- NAME: Alice

  SET CATALOG 'main';

``SET SCHEMA`` can change both at once, such as ``SET SCHEMA
'"archive".public'``.

Queries Across Catalogs
-----------------------

With ``main.vsql`` as the current catalog again:

.. code-block:: sql

  SELECT * FROM customers;
  -- ID: 1 NAME: Alice
  -- ID: 2 NAME: Bob

  SELECT * FROM "archive".public.orders WHERE customer_id = 2;
  -- ID: 12 CUSTOMER_ID: 2 TOTAL: 15

A table in any catalog can be used anywhere that a table can, such as in a
join:

.. code-block:: sql

  SELECT c.name, SUM(o.total) AS total
  FROM customers c
  JOIN "archive".public.orders o ON o.customer_id = c.id
  GROUP BY c.name;
  -- NAME: Alice TOTAL: 65
  -- NAME: Bob TOTAL: 15

Tables, schemas and sequences can be created, changed and dropped in another
catalog in the same way.

A ``FOREIGN KEY`` can't reference a table in another catalog:

.. code-block:: sql

  CREATE TABLE notes (
    id INT,
    customer_id INT REFERENCES "archive".public.customers (id)
  );
  -- error 0A000: FOREIGN KEY cannot reference a table in another catalog: "archive".PUBLIC.CUSTOMERS

Each catalog has its own ``INFORMATION_SCHEMA``, which only describes that
catalog:

.. code-block:: sql

  SELECT catalog_name
  FROM "archive".information_schema.information_schema_catalog_name;
  -- CATALOG_NAME: archive

Transactions Across Catalogs
----------------------------

A transaction includes every catalog of the connection, not only the current
one. So rows can be moved from one file to another, and either both files are
changed or neither is:

.. code-block:: sql

  CREATE TABLE "archive".public.customers (
    id INT NOT NULL,
    name VARCHAR(50),
    PRIMARY KEY (id)
  );

  START TRANSACTION;
  INSERT INTO "archive".public.customers SELECT * FROM customers WHERE id = 2;
  DELETE FROM customers WHERE id = 2;
  COMMIT;

  SELECT * FROM customers;
  -- ID: 1 NAME: Alice

  SELECT * FROM "archive".public.customers;
  -- ID: 2 NAME: Bob

A ``ROLLBACK`` undoes the changes to every catalog:

.. code-block:: sql

  START TRANSACTION;
  DELETE FROM customers;
  DELETE FROM "archive".public.customers;
  ROLLBACK;

  SELECT COUNT(*) FROM customers;
  -- COL1: 1

  SELECT COUNT(*) FROM "archive".public.customers;
  -- COL1: 1

``SET CATALOG`` doesn't start another transaction, so a ``START TRANSACTION``
after it fails with a ``25001`` if a transaction is already active.

Each file is locked on its own (see :doc:`locking`), and a ``COMMIT`` is
written to each file in turn, so a crash part way through a ``COMMIT`` can
leave some of the files changed (see :ref:`durability:Crash Recovery`).

See Also
--------

- :doc:`create-schema`
- :doc:`set-catalog`
- :doc:`set-schema`
