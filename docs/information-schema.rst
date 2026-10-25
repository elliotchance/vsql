Information Schema
==================

.. contents::

Every catalog has an ``INFORMATION_SCHEMA`` schema with tables that describe the
tables, columns and constraints in the catalog. They can be queried like any other table:

.. code-block:: sql

  CREATE TABLE products (id INT PRIMARY KEY, title VARCHAR(100) NOT NULL);

  SELECT table_name, table_type FROM information_schema.tables
  WHERE table_schema = 'PUBLIC';
  -- TABLE_NAME: PRODUCTS TABLE_TYPE: BASE TABLE

  SELECT column_name, data_type, character_maximum_length, is_nullable
  FROM information_schema.columns
  WHERE table_name = 'PRODUCTS';
  -- COLUMN_NAME: ID DATA_TYPE: INTEGER CHARACTER_MAXIMUM_LENGTH: NULL IS_NULLABLE: NO
  -- COLUMN_NAME: TITLE DATA_TYPE: CHARACTER VARYING CHARACTER_MAXIMUM_LENGTH: 100 IS_NULLABLE: NO

The tables are defined by the SQL standard as views (ISO/IEC 9075-11). vsql
doesn't have views, so they're built from the table definitions each time
they're read. A table that's created in a transaction is only described in that
transaction until it's committed.

The ``INFORMATION_SCHEMA`` can't be changed. Creating, changing or dropping
anything in it (or the schema itself) is a ``42501`` error. It isn't stored in
the database file, and isn't part of a dump. Virtual tables (see
:doc:`virtual-tables`) aren't described because they're part of a connection,
not the catalog.

``TABLES``
----------

One row for each table, including the tables of the ``INFORMATION_SCHEMA``
(which are a ``VIEW``). Rows are ordered by schema and table name.

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``
    - The fully qualified name of the table.

  * - ``TABLE_TYPE``
    - ``BASE TABLE``, or ``VIEW`` for the tables of the
      ``INFORMATION_SCHEMA``.

  * - ``IS_INSERTABLE_INTO``
    - ``YES``, or ``NO`` for the tables of the ``INFORMATION_SCHEMA``.

  * - ``IS_TYPED``
    - Always ``NO``.

  * - ``SELF_REFERENCING_COLUMN_NAME``, ``REFERENCE_GENERATION``,
      ``USER_DEFINED_TYPE_CATALOG``, ``USER_DEFINED_TYPE_SCHEMA``,
      ``USER_DEFINED_TYPE_NAME``, ``COMMIT_ACTION``
    - Always ``NULL`` (typed tables and temporary tables are not supported).

``COLUMNS``
-----------

One row for each column of each table in ``TABLES``.

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``
    - The fully qualified name of the table.

  * - ``COLUMN_NAME``
    - The name of the column.

  * - ``ORDINAL_POSITION``
    - The position of the column in the table, starting at 1.

  * - ``COLUMN_DEFAULT``
    - The SQL of the ``DEFAULT``, such as ``'it''s'`` or ``CURRENT_DATE``, or
      ``NULL`` if the column doesn't have one. A ``DEFAULT NULL`` is the text
      ``NULL``.

  * - ``IS_NULLABLE``
    - ``NO`` for a ``NOT NULL`` or ``PRIMARY KEY`` column, otherwise ``YES``.

  * - ``DATA_TYPE``
    - The name of the data type, without its size, such as
      ``CHARACTER VARYING``, ``NUMERIC``, ``TIMESTAMP`` or
      ``TIME WITH TIME ZONE``. A ``FLOAT`` is a ``DOUBLE PRECISION``.

  * - ``CHARACTER_MAXIMUM_LENGTH``, ``CHARACTER_OCTET_LENGTH``
    - For ``CHARACTER`` and ``CHARACTER VARYING``, the length in characters,
      and the most bytes that it can use (4 for each character in UTF-8).

  * - ``NUMERIC_PRECISION``, ``NUMERIC_PRECISION_RADIX``, ``NUMERIC_SCALE``
    - For numbers, the precision in binary digits (``SMALLINT`` is 16,
      ``INTEGER`` is 32, ``BIGINT`` is 64, ``REAL`` is 24 and
      ``DOUBLE PRECISION`` is 53) or decimal digits (``NUMERIC`` and
      ``DECIMAL``, which have a precision of 1000 if it isn't specified). The
      scale is ``NULL`` for ``REAL`` and ``DOUBLE PRECISION``.

  * - ``DATETIME_PRECISION``
    - For ``DATE`` (0), ``TIME`` and ``TIMESTAMP``, the fractional seconds
      precision.

  * - ``CHARACTER_SET_CATALOG``, ``CHARACTER_SET_SCHEMA``,
      ``CHARACTER_SET_NAME``
    - For ``CHARACTER`` and ``CHARACTER VARYING``, the catalog,
      ``INFORMATION_SCHEMA`` and ``UTF8``.

  * - ``DTD_IDENTIFIER``
    - The ordinal position, as text.

  * - ``IS_SELF_REFERENCING``, ``IS_IDENTITY``
    - Always ``NO``.

  * - ``IS_GENERATED``
    - Always ``NEVER``.

  * - ``IS_UPDATABLE``
    - ``YES``, or ``NO`` for the tables of the ``INFORMATION_SCHEMA``.

  * - ``INTERVAL_TYPE``, ``INTERVAL_PRECISION``, ``COLLATION_CATALOG``,
      ``COLLATION_SCHEMA``, ``COLLATION_NAME``, ``DOMAIN_CATALOG``,
      ``DOMAIN_SCHEMA``, ``DOMAIN_NAME``, ``UDT_CATALOG``, ``UDT_SCHEMA``,
      ``UDT_NAME``, ``SCOPE_CATALOG``, ``SCOPE_SCHEMA``, ``SCOPE_NAME``,
      ``MAXIMUM_CARDINALITY``, ``IDENTITY_GENERATION``, ``IDENTITY_START``,
      ``IDENTITY_INCREMENT``, ``IDENTITY_MAXIMUM``, ``IDENTITY_MINIMUM``,
      ``IDENTITY_CYCLE``, ``GENERATION_EXPRESSION``
    - Always ``NULL`` (intervals, collations, domains, user-defined types,
      reference types, arrays, identity columns and generated columns are not
      supported).

``CHECK_CONSTRAINTS``
---------------------

One row for each check constraint of each table (but not the tables of the
``INFORMATION_SCHEMA``). A ``NOT NULL`` column is the same as a
``CHECK (column IS NOT NULL)``, so it's a check constraint too. That includes
the columns of a ``PRIMARY KEY``, which are always ``NOT NULL``. Rows are
ordered by schema and table name, then the ``NOT NULL`` columns in the order of
the columns, and then the ``CHECK`` constraints in the order they're defined.

.. code-block:: sql

  CREATE TABLE products (id INT PRIMARY KEY, price INT CHECK (price > 0));

  SELECT constraint_name, check_clause FROM information_schema.check_constraints;
  -- CONSTRAINT_NAME: PRODUCTS_NOT_NULL_1 CHECK_CLAUSE: ID IS NOT NULL
  -- CONSTRAINT_NAME: PRODUCTS_CHECK_1 CHECK_CLAUSE: PRICE > 0

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``CONSTRAINT_CATALOG``, ``CONSTRAINT_SCHEMA``
    - The catalog and schema of the table.

  * - ``CONSTRAINT_NAME``
    - Constraints can't be named yet, so each one is named after its table:
      ``<table>_NOT_NULL_<n>`` for the ``NOT NULL`` of the nth column, or
      ``<table>_CHECK_<n>`` for the nth ``CHECK`` constraint (counting
      ``CHECK`` constraints on columns and on the table together).

  * - ``CHECK_CLAUSE``
    - The SQL of the condition, such as ``PRICE > 0``, or ``NULL`` if it's
      longer than 10485760 characters.

``TABLE_CONSTRAINTS``
---------------------

One row for each constraint of each table (but not the tables of the
``INFORMATION_SCHEMA``): the ``PRIMARY KEY``, then each ``UNIQUE``, then each
``FOREIGN KEY``, then the same check constraints as ``CHECK_CONSTRAINTS``, in
the same order and with the same names.

.. code-block:: sql

  CREATE TABLE products (id INT PRIMARY KEY, code INT UNIQUE, price INT CHECK (price > 0));

  SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
  -- CONSTRAINT_NAME: PRODUCTS_PRIMARY_KEY CONSTRAINT_TYPE: PRIMARY KEY
  -- CONSTRAINT_NAME: PRODUCTS_UNIQUE_1 CONSTRAINT_TYPE: UNIQUE
  -- CONSTRAINT_NAME: PRODUCTS_NOT_NULL_1 CONSTRAINT_TYPE: CHECK
  -- CONSTRAINT_NAME: PRODUCTS_CHECK_1 CONSTRAINT_TYPE: CHECK

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``CONSTRAINT_CATALOG``, ``CONSTRAINT_SCHEMA``
    - The catalog and schema of the table.

  * - ``CONSTRAINT_NAME``
    - ``<table>_PRIMARY_KEY`` for the ``PRIMARY KEY``, ``<table>_UNIQUE_<n>``
      for the nth ``UNIQUE`` and ``<table>_FOREIGN_KEY_<n>`` for the nth
      ``FOREIGN KEY`` (counting constraints on columns and on the table
      together), otherwise the same as ``CHECK_CONSTRAINTS``.

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``
    - The table the constraint is on.

  * - ``CONSTRAINT_TYPE``
    - ``PRIMARY KEY``, ``UNIQUE``, ``FOREIGN KEY`` or ``CHECK``.

  * - ``IS_DEFERRABLE``, ``INITIALLY_DEFERRED``
    - Always ``NO`` (constraints can't be deferred).

  * - ``ENFORCED``
    - Always ``YES`` (``NOT ENFORCED`` is not supported).

``REFERENTIAL_CONSTRAINTS``
---------------------------

One row for each ``FOREIGN KEY`` (see :doc:`create-table`), in the same order
and with the same names as ``TABLE_CONSTRAINTS``.

.. code-block:: sql

  CREATE TABLE categories (id INT PRIMARY KEY);
  CREATE TABLE products (category_id INT REFERENCES categories);

  SELECT constraint_name, unique_constraint_name FROM information_schema.referential_constraints;
  -- CONSTRAINT_NAME: PRODUCTS_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_NAME: CATEGORIES_PRIMARY_KEY

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``CONSTRAINT_CATALOG``, ``CONSTRAINT_SCHEMA``, ``CONSTRAINT_NAME``
    - The ``FOREIGN KEY``, which has the catalog and schema of its table.

  * - ``UNIQUE_CONSTRAINT_CATALOG``, ``UNIQUE_CONSTRAINT_SCHEMA``,
      ``UNIQUE_CONSTRAINT_NAME``
    - The ``PRIMARY KEY`` or ``UNIQUE`` of the referenced table that has the
      referenced columns, with its name in ``TABLE_CONSTRAINTS``.

  * - ``MATCH_OPTION``
    - Always ``NONE`` (``MATCH`` is not supported).

  * - ``UPDATE_RULE``, ``DELETE_RULE``
    - Always ``NO ACTION`` (``ON UPDATE`` and ``ON DELETE`` are not supported).

The types of the columns of these tables are the domains of the
``INFORMATION_SCHEMA`` in the standard: a name is a ``CHARACTER VARYING(128)``,
other text is a ``CHARACTER VARYING(10485760)``, a number is an ``INTEGER`` and
``YES`` or ``NO`` is a ``CHARACTER VARYING(3)``.
