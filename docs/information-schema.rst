Information Schema
==================

.. contents::

Every catalog has an ``INFORMATION_SCHEMA`` schema with tables that describe the
schemas, tables, columns, constraints, sequences and routines in the catalog. They can be queried like any other table:

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

``SCHEMATA``
------------

One row for each schema, including the ``INFORMATION_SCHEMA`` and ``VSQL``
(see :doc:`vsql-schema`) schemas, ordered by name.

.. code-block:: sql

  CREATE SCHEMA sales;

  SELECT schema_name, schema_owner FROM information_schema.schemata;
  -- SCHEMA_NAME: INFORMATION_SCHEMA SCHEMA_OWNER: _SYSTEM
  -- SCHEMA_NAME: PUBLIC SCHEMA_OWNER: _SYSTEM
  -- SCHEMA_NAME: SALES SCHEMA_OWNER: _SYSTEM
  -- SCHEMA_NAME: VSQL SCHEMA_OWNER: _SYSTEM

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``CATALOG_NAME``, ``SCHEMA_NAME``
    - The catalog and name of the schema.

  * - ``SCHEMA_OWNER``
    - Always ``_SYSTEM``. vsql doesn't have users yet, so ``_SYSTEM`` is the
      default (and only) user, and it owns everything. It can only be written
      as a delimited identifier (``"_SYSTEM"``), so it can't be the same as a
      user that's created later. The SQL standard makes the
      ``INFORMATION_SCHEMA`` its own owner, but in vsql it's ``_SYSTEM`` too.

  * - ``DEFAULT_CHARACTER_SET_CATALOG``, ``DEFAULT_CHARACTER_SET_SCHEMA``,
      ``DEFAULT_CHARACTER_SET_NAME``
    - The catalog, ``INFORMATION_SCHEMA`` and ``UTF8`` (see
      ``CHARACTER_SETS``).

  * - ``SQL_PATH``
    - Always ``NULL`` (SQL paths are not supported).

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

``VIEWS``
---------

One row for each view in ``TABLES``, in the same order. Views can't be created
yet, so these are the tables of the ``INFORMATION_SCHEMA``.

.. code-block:: sql

  SELECT table_name, check_option, is_updatable FROM information_schema.views
  WHERE table_name = 'TABLES';
  -- TABLE_NAME: TABLES CHECK_OPTION: NONE IS_UPDATABLE: NO

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``
    - The fully qualified name of the view.

  * - ``VIEW_DEFINITION``
    - The SQL of the view's query. It's ``NULL`` for the tables of the
      ``INFORMATION_SCHEMA``, which are built by vsql rather than by a query.

  * - ``CHECK_OPTION``
    - Always ``NONE``.

  * - ``IS_UPDATABLE``, ``INSERTABLE_INTO``
    - Always ``NO``.

``VIEW_COLUMN_USAGE``, ``VIEW_ROUTINE_USAGE`` and ``VIEW_TABLE_USAGE``
----------------------------------------------------------------------

The columns, routines and tables that each view uses. They're always empty,
because the tables of the ``INFORMATION_SCHEMA`` (the only views) aren't
described by them. ``VIEW_COLUMN_USAGE`` and ``VIEW_TABLE_USAGE`` have the
``VIEW_CATALOG``, ``VIEW_SCHEMA`` and ``VIEW_NAME`` of the view, then the
``TABLE_CATALOG``, ``TABLE_SCHEMA`` and ``TABLE_NAME`` of a table that it uses
(and ``COLUMN_NAME`` for a column). ``VIEW_ROUTINE_USAGE`` has the
``TABLE_CATALOG``, ``TABLE_SCHEMA`` and ``TABLE_NAME`` of the view, then the
``SPECIFIC_CATALOG``, ``SPECIFIC_SCHEMA`` and ``SPECIFIC_NAME`` of a routine.

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
      ``NULL``. It's the text as it was written, so ``DEFAULT +.5`` is
      ``+.5``, rather than ``0.5``. A table created by an older version has
      the text that vsql printed it as.

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

  * - ``IS_SELF_REFERENCING``
    - Always ``NO``.

  * - ``IS_IDENTITY``
    - ``YES`` for an identity column, otherwise ``NO``.

  * - ``IDENTITY_GENERATION``
    - ``ALWAYS`` or ``BY DEFAULT`` for an identity column, otherwise ``NULL``.

  * - ``IDENTITY_START``, ``IDENTITY_INCREMENT``, ``IDENTITY_MAXIMUM``,
      ``IDENTITY_MINIMUM``
    - The ``START WITH``, ``INCREMENT BY``, ``MAXVALUE`` and ``MINVALUE`` of the
      sequence of an identity column, as text, otherwise ``NULL``.

  * - ``IDENTITY_CYCLE``
    - ``YES`` or ``NO`` for an identity column, otherwise ``NULL``.

  * - ``IS_GENERATED``
    - ``ALWAYS`` for a generated column, otherwise ``NEVER``.

  * - ``GENERATION_EXPRESSION``
    - The expression of a generated column, with its parentheses, as it was
      written (such as ``(x + 1)``), otherwise ``NULL``. A table created by
      an older version has the text that vsql printed it as.

  * - ``IS_UPDATABLE``
    - ``YES``, or ``NO`` for the tables of the ``INFORMATION_SCHEMA``.

  * - ``INTERVAL_TYPE``, ``INTERVAL_PRECISION``, ``COLLATION_CATALOG``,
      ``COLLATION_SCHEMA``, ``COLLATION_NAME``, ``DOMAIN_CATALOG``,
      ``DOMAIN_SCHEMA``, ``DOMAIN_NAME``, ``UDT_CATALOG``, ``UDT_SCHEMA``,
      ``UDT_NAME``, ``SCOPE_CATALOG``, ``SCOPE_SCHEMA``, ``SCOPE_NAME``,
      ``MAXIMUM_CARDINALITY``
    - Always ``NULL`` (intervals, collations, domains, user-defined types,
      reference types and arrays are not supported).

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
    - The name of the constraint. A constraint that wasn't given a name is
      named after its table (see "Constraint Names" in :doc:`create-table`),
      such as ``<table>_NOT_NULL_<n>`` for the ``NOT NULL`` of the nth column,
      or ``<table>_CHECK_<n>`` for a ``CHECK`` constraint.

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
    - The name of the constraint, such as ``<table>_PRIMARY_KEY``,
      ``<table>_UNIQUE_<n>`` or ``<table>_FOREIGN_KEY_<n>`` for a constraint
      that wasn't given a name (see "Constraint Names" in
      :doc:`create-table`).

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``
    - The table the constraint is on.

  * - ``CONSTRAINT_TYPE``
    - ``PRIMARY KEY``, ``UNIQUE``, ``FOREIGN KEY`` or ``CHECK``.

  * - ``IS_DEFERRABLE``, ``INITIALLY_DEFERRED``
    - ``YES`` or ``NO`` (see "Deferrable Constraints" in :doc:`create-table`).

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
    - ``FULL`` or ``PARTIAL`` (the ``MATCH``), or ``NONE`` for ``MATCH SIMPLE``.

  * - ``UPDATE_RULE``
    - ``CASCADE``, ``SET NULL``, ``SET DEFAULT`` or ``NO ACTION`` (the
      ``ON UPDATE``).

  * - ``DELETE_RULE``
    - ``CASCADE``, ``SET NULL``, ``SET DEFAULT`` or ``NO ACTION`` (the
      ``ON DELETE``).

``KEY_COLUMN_USAGE``
--------------------

One row for each column of each ``PRIMARY KEY``, ``UNIQUE`` and ``FOREIGN KEY``
(see :doc:`create-table`), in the same order and with the same names as
``TABLE_CONSTRAINTS``.

.. code-block:: sql

  CREATE TABLE categories (id INT PRIMARY KEY);
  CREATE TABLE products (id INT PRIMARY KEY, category_id INT REFERENCES categories);

  SELECT constraint_name, table_name, column_name, ordinal_position, position_in_unique_constraint
  FROM information_schema.key_column_usage;
  -- CONSTRAINT_NAME: CATEGORIES_PRIMARY_KEY TABLE_NAME: CATEGORIES COLUMN_NAME: ID ORDINAL_POSITION: 1 POSITION_IN_UNIQUE_CONSTRAINT: NULL
  -- CONSTRAINT_NAME: PRODUCTS_PRIMARY_KEY TABLE_NAME: PRODUCTS COLUMN_NAME: ID ORDINAL_POSITION: 1 POSITION_IN_UNIQUE_CONSTRAINT: NULL
  -- CONSTRAINT_NAME: PRODUCTS_FOREIGN_KEY_1 TABLE_NAME: PRODUCTS COLUMN_NAME: CATEGORY_ID ORDINAL_POSITION: 1 POSITION_IN_UNIQUE_CONSTRAINT: 1

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``CONSTRAINT_CATALOG``, ``CONSTRAINT_SCHEMA``, ``CONSTRAINT_NAME``
    - The key, which has the catalog and schema of its table.

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``, ``COLUMN_NAME``
    - The column.

  * - ``ORDINAL_POSITION``
    - The position of the column in the key (from 1).

  * - ``POSITION_IN_UNIQUE_CONSTRAINT``
    - For a ``FOREIGN KEY``, the position of the referenced column in the
      ``PRIMARY KEY`` or ``UNIQUE`` that it references (see
      ``REFERENTIAL_CONSTRAINTS``). Otherwise, ``NULL``.

``CONSTRAINT_COLUMN_USAGE``
---------------------------

One row for each column that a constraint uses, in the same order and with the
same names as ``TABLE_CONSTRAINTS``:

- The columns of a ``PRIMARY KEY`` or ``UNIQUE``.
- The columns of the ``PRIMARY KEY`` or ``UNIQUE`` that a ``FOREIGN KEY``
  references (see ``REFERENTIAL_CONSTRAINTS``), which are in the referenced
  table. The columns of the ``FOREIGN KEY`` itself are in
  ``KEY_COLUMN_USAGE``.
- The column of a ``NOT NULL``.
- The columns that a ``CHECK`` uses in its condition, in the order of the
  columns of the table.

.. code-block:: sql

  CREATE TABLE categories (id INT PRIMARY KEY);
  CREATE TABLE products (category_id INT REFERENCES categories, price INT CHECK (price > 0));

  SELECT table_name, column_name, constraint_name
  FROM information_schema.constraint_column_usage;
  -- TABLE_NAME: CATEGORIES COLUMN_NAME: ID CONSTRAINT_NAME: CATEGORIES_PRIMARY_KEY
  -- TABLE_NAME: CATEGORIES COLUMN_NAME: ID CONSTRAINT_NAME: CATEGORIES_NOT_NULL_1
  -- TABLE_NAME: CATEGORIES COLUMN_NAME: ID CONSTRAINT_NAME: PRODUCTS_FOREIGN_KEY_1
  -- TABLE_NAME: PRODUCTS COLUMN_NAME: PRICE CONSTRAINT_NAME: PRODUCTS_CHECK_1

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``, ``COLUMN_NAME``
    - The column.

  * - ``CONSTRAINT_CATALOG``, ``CONSTRAINT_SCHEMA``, ``CONSTRAINT_NAME``
    - The constraint, which has the catalog and schema of its table.

``CONSTRAINT_TABLE_USAGE``
--------------------------

One row for each table that a constraint uses, in the same order and with the
same names as ``TABLE_CONSTRAINTS``: the table of a ``PRIMARY KEY`` or
``UNIQUE``, and the referenced table of a ``FOREIGN KEY``. A ``CHECK`` can only
use a table in a subquery, which isn't supported, so they're never in it.

.. code-block:: sql

  CREATE TABLE categories (id INT PRIMARY KEY);
  CREATE TABLE products (category_id INT REFERENCES categories);

  SELECT table_name, constraint_name FROM information_schema.constraint_table_usage;
  -- TABLE_NAME: CATEGORIES CONSTRAINT_NAME: CATEGORIES_PRIMARY_KEY
  -- TABLE_NAME: CATEGORIES CONSTRAINT_NAME: PRODUCTS_FOREIGN_KEY_1

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``
    - The table.

  * - ``CONSTRAINT_CATALOG``, ``CONSTRAINT_SCHEMA``, ``CONSTRAINT_NAME``
    - The constraint, which has the catalog and schema of its table.

``COLUMN_COLUMN_USAGE``
-----------------------

One row for each column that a generated column uses in its expression,
ordered by table, then by the generated column, then by the column that it
uses (in the order of the columns of the table).

.. code-block:: sql

  CREATE TABLE products (price INT, tax INT, total INT GENERATED ALWAYS AS (price + tax));

  SELECT column_name, dependent_column FROM information_schema.column_column_usage;
  -- COLUMN_NAME: PRICE DEPENDENT_COLUMN: TOTAL
  -- COLUMN_NAME: TAX DEPENDENT_COLUMN: TOTAL

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``TABLE_CATALOG``, ``TABLE_SCHEMA``, ``TABLE_NAME``
    - The table.

  * - ``COLUMN_NAME``
    - The column that's used.

  * - ``DEPENDENT_COLUMN``
    - The generated column.

``SEQUENCES``
-------------

One row for each sequence (see :doc:`create-sequence`), ordered by schema and name.
The sequence of an identity column is in ``COLUMNS`` instead.

.. code-block:: sql

  CREATE SEQUENCE invoice_number START WITH 1000 INCREMENT BY 10;

  SELECT sequence_name, data_type, minimum_value, maximum_value, increment
  FROM information_schema.sequences;
  -- SEQUENCE_NAME: INVOICE_NUMBER DATA_TYPE: BIGINT MINIMUM_VALUE: 1 MAXIMUM_VALUE: 9223372036854775807 INCREMENT: 10

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``SEQUENCE_CATALOG``, ``SEQUENCE_SCHEMA``, ``SEQUENCE_NAME``
    - The fully qualified name of the sequence.

  * - ``DATA_TYPE``, ``NUMERIC_PRECISION``, ``NUMERIC_PRECISION_RADIX``,
      ``NUMERIC_SCALE``
    - The data type, the same as in ``COLUMNS``.

  * - ``MAXIMUM_VALUE``, ``MINIMUM_VALUE``, ``INCREMENT``
    - The ``MAXVALUE``, ``MINVALUE`` and ``INCREMENT BY``, as text. A sequence
      without a ``MAXVALUE`` or ``MINVALUE`` has the one that's used instead.

  * - ``CYCLE_OPTION``
    - ``YES`` for a ``CYCLE``, otherwise ``NO``.

``ROUTINES``
------------

One row for each routine, ordered by name. The routines are the functions of
the ``VSQL`` schema (see :doc:`vsql-schema`), which are the functions that
vsql has beyond the SQL standard. A function of the SQL standard (such as
``ABS``) isn't a routine, and neither is an aggregate function.

.. code-block:: sql

  SELECT specific_name, data_type, is_deterministic
  FROM information_schema.routines
  WHERE routine_name IN ('NOW', 'SIGN');
  -- SPECIFIC_NAME: NOW_1 DATA_TYPE: TIMESTAMP WITH TIME ZONE IS_DETERMINISTIC: NO
  -- SPECIFIC_NAME: SIGN_1 DATA_TYPE: DOUBLE PRECISION IS_DETERMINISTIC: YES
  -- SPECIFIC_NAME: SIGN_2 DATA_TYPE: NUMERIC IS_DETERMINISTIC: YES
  -- SPECIFIC_NAME: SIGN_3 DATA_TYPE: SMALLINT IS_DETERMINISTIC: YES
  -- SPECIFIC_NAME: SIGN_4 DATA_TYPE: INTEGER IS_DETERMINISTIC: YES
  -- SPECIFIC_NAME: SIGN_5 DATA_TYPE: BIGINT IS_DETERMINISTIC: YES

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``SPECIFIC_CATALOG``, ``SPECIFIC_SCHEMA``, ``SPECIFIC_NAME``
    - The specific name of the routine, which is different for each overload
      of a function. It's the name of the function and the number of the
      overload, such as ``SIGN_2``.

  * - ``ROUTINE_CATALOG``, ``ROUTINE_SCHEMA``, ``ROUTINE_NAME``
    - The name of the function, in the ``VSQL`` schema.

  * - ``ROUTINE_TYPE``
    - Always ``FUNCTION``.

  * - ``DATA_TYPE`` to ``INTERVAL_PRECISION``
    - The data type of the result, the same as in ``COLUMNS``. A character
      string result can have any length, so its maximum length is the longest
      character string.

  * - ``DTD_IDENTIFIER``
    - Always ``0``, which identifies the result (a parameter is identified by
      its position, see ``PARAMETERS``).

  * - ``ROUTINE_BODY``, ``EXTERNAL_NAME``, ``EXTERNAL_LANGUAGE``,
      ``PARAMETER_STYLE``
    - ``EXTERNAL``, the name of the function, ``C`` and ``GENERAL``. Each
      function is an external routine that's built into vsql (which is
      compiled to C), and its arguments are only the values.

  * - ``IS_DETERMINISTIC``
    - ``NO`` for a function that can return a different result for the same
      arguments, such as ``NOW`` or ``RANDOM``, otherwise ``YES``. A function
      that's registered with ``register_function`` is always ``NO``.

  * - ``SQL_DATA_ACCESS``
    - ``NO SQL``, except for a function that's registered with
      ``register_function``, which is ``MODIFIES SQL DATA`` because it can use
      its connection for anything.

  * - ``IS_NULL_CALL``
    - ``YES`` for a function that returns ``NULL`` when any argument is
      ``NULL`` (every built-in function), ``NO`` for a function that's always
      called (a function that's registered with ``register_function``, or a
      PostgreSQL function).

  * - ``SCHEMA_LEVEL_ROUTINE``, ``MAX_DYNAMIC_RESULT_SETS``,
      ``IS_USER_DEFINED_CAST``, ``AS_LOCATOR``, ``IS_UDT_DEPENDENT``
    - ``YES``, ``0``, ``NO``, ``NO`` and ``NO``.

  * - ``SECURITY_TYPE``
    - Always ``IMPLEMENTATION DEFINED``. vsql doesn't have users yet, so a
      routine runs the same way for everyone.

  * - ``CREATED``, ``LAST_ALTERED``
    - Always ``NULL``, since the routines are built into vsql.

  * - The other columns
    - Always ``NULL``. There are no modules, user-defined types, routine
      definitions, SQL paths, transforms, savepoint levels or result casts.

``PARAMETERS``
--------------

One row for each parameter of each routine in ``ROUTINES``, in the same order,
then by position.

.. code-block:: sql

  SELECT specific_name, ordinal_position, data_type
  FROM information_schema.parameters
  WHERE specific_name = 'SPLIT_PART_1';
  -- SPECIFIC_NAME: SPLIT_PART_1 ORDINAL_POSITION: 1 DATA_TYPE: CHARACTER VARYING
  -- SPECIFIC_NAME: SPLIT_PART_1 ORDINAL_POSITION: 2 DATA_TYPE: CHARACTER VARYING
  -- SPECIFIC_NAME: SPLIT_PART_1 ORDINAL_POSITION: 3 DATA_TYPE: BIGINT

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``SPECIFIC_CATALOG``, ``SPECIFIC_SCHEMA``, ``SPECIFIC_NAME``
    - The specific name of the routine (see ``ROUTINES``).

  * - ``ORDINAL_POSITION``
    - The position of the parameter, from 1.

  * - ``PARAMETER_MODE``, ``IS_RESULT``, ``AS_LOCATOR``
    - Always ``IN``, ``NO`` and ``NO``.

  * - ``DATA_TYPE`` to ``INTERVAL_PRECISION``
    - The data type of the parameter, the same as in ``ROUTINES``.

  * - ``DTD_IDENTIFIER``
    - The position of the parameter, as text.

  * - The other columns
    - Always ``NULL``. The parameters don't have names, and there are no
      transforms or user-defined types.

``CHARACTER_SETS``
------------------

One row for each character set. ``UTF8`` is the only one.

.. code-block:: sql

  SELECT character_set_name, character_repertoire, form_of_use, default_collate_name
  FROM information_schema.character_sets;
  -- CHARACTER_SET_NAME: UTF8 CHARACTER_REPERTOIRE: UCS FORM_OF_USE: UTF8 DEFAULT_COLLATE_NAME: UCS_BASIC

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``CHARACTER_SET_CATALOG``, ``CHARACTER_SET_SCHEMA``,
      ``CHARACTER_SET_NAME``
    - The catalog, ``INFORMATION_SCHEMA`` and ``UTF8`` (the same as the
      character set of a column in ``COLUMNS``).

  * - ``CHARACTER_REPERTOIRE``
    - ``UCS`` (Unicode).

  * - ``FORM_OF_USE``
    - ``UTF8``, the encoding.

  * - ``DEFAULT_COLLATE_CATALOG``, ``DEFAULT_COLLATE_SCHEMA``,
      ``DEFAULT_COLLATE_NAME``
    - The catalog, ``INFORMATION_SCHEMA`` and ``UCS_BASIC``. Strings are
      compared by their code points. Trailing spaces don't matter (the
      ``PAD SPACE`` characteristic), so ``'a' = 'a  '`` is ``TRUE``, even for
      ``VARCHAR``.

``INFORMATION_SCHEMA_CATALOG_NAME``
-----------------------------------

One row, with the name of the catalog (the database file, or the name it was
given, see :doc:`set-catalog`).

.. code-block:: sql

  SELECT catalog_name FROM information_schema.information_schema_catalog_name;
  -- CATALOG_NAME: :memory:

The SQL standard makes it a base table, but in vsql it's a ``VIEW`` like the
others (in ``TABLES``).

``SQL_FEATURES``
----------------

One row for each feature and subfeature of the SQL standard, and whether vsql
supports it. The rows are the same as the :doc:`sql-compliance` pages (they're
built from them), with each feature in one row even when it's on the page of
more than one part. A feature is only supported (✅ on every page that it's
on) when it's fully supported. Rows are ordered by feature and subfeature.

.. code-block:: sql

  SELECT feature_id, sub_feature_id, sub_feature_name, is_supported
  FROM information_schema.sql_features
  WHERE feature_id = 'E011' AND sub_feature_id IN (' ', '01');
  -- FEATURE_ID: E011 SUB_FEATURE_ID:   SUB_FEATURE_NAME:   IS_SUPPORTED: YES
  -- FEATURE_ID: E011 SUB_FEATURE_ID: 01 SUB_FEATURE_NAME: INTEGER and SMALLINT data types (including all spellings) IS_SUPPORTED: YES

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``FEATURE_ID``, ``FEATURE_NAME``
    - The feature, such as ``E011`` and ``Numeric data types``.

  * - ``SUB_FEATURE_ID``, ``SUB_FEATURE_NAME``
    - The subfeature, such as ``01`` (for ``E011-01``). For a feature, they're
      a single space.

  * - ``IS_SUPPORTED``
    - ``YES`` or ``NO``.

  * - ``IS_VERIFIED_BY``, ``COMMENTS``
    - Always ``NULL``.

``SQL_IMPLEMENTATION_INFO``
---------------------------

One row for each piece of information about vsql itself. It's the same
information that ``SQLGetInfo`` of the C API returns (see
:doc:`sql-compliance-9075-3`).

.. code-block:: sql

  SELECT implementation_info_name, integer_value, character_value
  FROM information_schema.sql_implementation_info
  WHERE implementation_info_id IN ('17', '28');
  -- IMPLEMENTATION_INFO_NAME: DBMS NAME INTEGER_VALUE: NULL CHARACTER_VALUE: vsql
  -- IMPLEMENTATION_INFO_NAME: IDENTIFIER CASE INTEGER_VALUE: 1 CHARACTER_VALUE: NULL

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``IMPLEMENTATION_INFO_ID``, ``IMPLEMENTATION_INFO_NAME``
    - The code (as text) and name of the item, which are the ones from the SQL
      standard, such as ``17`` for ``DBMS NAME``, or vsql's own items below.

  * - ``INTEGER_VALUE``, ``CHARACTER_VALUE``
    - The value, which is in one of them (the other one is ``NULL``, or both
      are when there's no value). The ``DBMS VERSION`` is the number of the
      release, such as ``01.02.0003`` for ``v1.2.3``, or ``00.00.0000`` when
      vsql wasn't built for a release. The ``DATA SOURCE NAME`` and ``SERVER
      NAME`` are the path of the database file (or ``:memory:``).

  * - ``COMMENTS``
    - What the value means.

vsql also has its own items, with IDs from ``11000`` (the standard leaves 11000
to 14999 for them). The ``BUILD`` items are set when vsql is compiled, and the
others are read when they're used. Each one is a single value, so it never has
to be split apart:

.. list-table::
  :header-rows: 1

  * - ID
    - Name
    - Value

  * - ``11000``
    - ``BUILD VERSION``
    - The release, such as ``v1.2.3``, or ``NULL`` when vsql wasn't built for a
      release.

  * - ``11001``
    - ``BUILD COMMIT``
    - The git commit of the release, or ``NULL`` when vsql wasn't built for a
      release.

  * - ``11002``
    - ``BUILD DATE``
    - The date (in UTC) that vsql was compiled, such as ``2026-11-12``.

  * - ``11003``
    - ``BUILD V VERSION``
    - The version of V that compiled vsql, such as ``0.5.2``.

  * - ``11004``
    - ``BUILD V COMMIT``
    - The commit of V that compiled vsql, such as ``5634a1f``.

  * - ``11005``
    - ``BUILD C COMPILER``
    - The C compiler that compiled vsql, such as ``clang``.

  * - ``11006``
    - ``OPERATING SYSTEM``
    - The operating system that vsql is running on, such as ``macos``.

  * - ``11007``
    - ``MACHINE``
    - The hardware that vsql is running on, such as ``arm64``.

  * - ``11008``
    - ``FILE READ VERSION``
    - (``INTEGER_VALUE``) The oldest file format that can read the database
      file, or ``NULL`` for ``:memory:``. See :doc:`file-format`.

  * - ``11009``
    - ``FILE WRITE VERSION``
    - (``INTEGER_VALUE``) The oldest file format that can change the database
      file, or ``NULL`` for ``:memory:``.

``SQLGetInfo`` of the C API returns them too, with the ``SQL_VSQL_`` constants
(such as ``SQL_VSQL_BUILD_DATE``).

``SQL_SIZING``
--------------

One row for each limit, such as the longest name or the most columns in a
table. ``SQLGetInfo`` returns the same limits.

.. code-block:: sql

  SELECT sizing_name, supported_value
  FROM information_schema.sql_sizing
  WHERE sizing_id IN (30, 101);
  -- SIZING_NAME: MAXIMUM COLUMN NAME LENGTH SUPPORTED_VALUE: 128
  -- SIZING_NAME: MAXIMUM COLUMNS IN TABLE SUPPORTED_VALUE: 1600

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``SIZING_ID``, ``SIZING_NAME``
    - The code and name of the limit, which are the ones from the SQL standard.

  * - ``SUPPORTED_VALUE``
    - The limit, ``0`` if there isn't one, or ``NULL`` if vsql doesn't support
      anything that it applies to (such as ``MAXIMUM CURRENT ROLE LENGTH``).

  * - ``COMMENTS``
    - What the limit is.

``SQL_PACKAGES``
----------------

One row for each package of SQL:2003, which is a group of optional features.
SQL:2023 doesn't have packages any more, but the view is still in Part 11. A
package is only supported when Core SQL (the mandatory features) and all of its
features are, so none of them are yet.

.. code-block:: sql

  SELECT id, name, is_supported FROM information_schema.sql_packages
  WHERE id = 'PKG010';
  -- ID: PKG010 NAME: OLAP IS_SUPPORTED: NO

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``ID``, ``NAME``
    - The package, such as ``PKG010`` and ``OLAP``.

  * - ``IS_SUPPORTED``
    - ``YES`` or ``NO``.

  * - ``IS_VERIFIED_BY``
    - Always ``NULL``.

  * - ``COMMENTS``
    - How many of the features of the package are supported, such as ``0 of
      the 4 features are supported.``

``SQL_PARTS``
-------------

One row for each part of the SQL standard, and whether vsql supports it. A part
is only supported when all of its mandatory features are. The parts that have a
:doc:`sql-compliance` page have the number of mandatory features from that page.

.. code-block:: sql

  SELECT part, name, is_supported FROM information_schema.sql_parts
  WHERE part = '2';
  -- PART: 2 NAME: Foundation (SQL/Foundation) IS_SUPPORTED: NO

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``PART``, ``NAME``
    - The number and name of the part, such as ``2`` and
      ``Foundation (SQL/Foundation)``.

  * - ``IS_SUPPORTED``
    - ``YES`` or ``NO``.

  * - ``IS_VERIFIED_BY``
    - Always ``NULL``.

  * - ``COMMENTS``
    - How many of the mandatory features are supported, such as ``0 of the 1
      mandatory features are supported.``, or ``NULL`` for a part without a
      page.

``SQL_SIZING_PROFILES``
-----------------------

One row for each limit that a profile of the SQL standard requires. It's always
empty, because no profiles are defined.

.. list-table::
  :header-rows: 1

  * - Column
    - Description

  * - ``SIZING_ID``, ``SIZING_NAME``
    - The limit, as in ``SQL_SIZING``.

  * - ``PROFILE_ID``, ``PROFILE_NAME``
    - The profile.

  * - ``REQUIRED_VALUE``
    - The limit that the profile requires.

  * - ``COMMENTS``
    - What the limit is.

Short Name Views
----------------

Some of the tables also have a short name view, which has the same rows and
columns, but with names that are no longer than 18 characters (so they can be
used without Feature F391, "Long identifiers"):

.. list-table::
  :header-rows: 1

  * - Table
    - Short name view
    - Renamed columns

  * - ``CHARACTER_SETS``
    - ``CHARACTER_SETS_S``
    - ``CHAR_SET_CATALOG``, ``CHAR_SET_SCHEMA``, ``CHAR_REPERTOIRE``,
      ``DEF_COLLATE_CAT``, ``DEF_COLLATE_SCHEMA`` and ``DEF_COLLATE_NAME``.

  * - ``COLUMN_COLUMN_USAGE``
    - ``COL_COL_USAGE``
    - None.

  * - ``COLUMNS``
    - ``COLUMNS_S``
    - ``CHAR_MAX_LENGTH``, ``CHAR_OCTET_LENGTH``, ``NUMERIC_PREC_RADIX``,
      ``CHAR_SET_CATALOG``, ``CHAR_SET_SCHEMA``, ``MAX_CARDINALITY``,
      ``IS_SELF_REF``, ``ID_GENERATION``, ``ID_START``, ``ID_INCREMENT``,
      ``ID_MAXIMUM``, ``ID_MINIMUM``, ``ID_CYCLE`` and ``GENERATION_EXPR``.

  * - ``CONSTRAINT_COLUMN_USAGE``
    - ``CONSTR_COL_USAGE``
    - None.

  * - ``CONSTRAINT_TABLE_USAGE``
    - ``CONSTR_TABLE_USAGE``
    - None.

  * - ``INFORMATION_SCHEMA_CATALOG_NAME``
    - ``CATALOG_NAME``
    - None.

  * - ``KEY_COLUMN_USAGE``
    - ``KEY_COLUMN_USAGE_S``
    - ``POSITION_IN_UC``.

  * - ``PARAMETERS``
    - ``PARAMETERS_S``
    - ``FROM_SQL_SPEC_CAT``, ``FROM_SQL_SPEC_SCH``, ``FROM_SQL_SPEC_NAME``,
      ``TO_SQL_SPEC_CAT``, ``TO_SQL_SPEC_SCHEMA``, ``TO_SQL_SPEC_NAME``,
      ``CHAR_MAX_LENGTH``, ``CHAR_OCTET_LENGTH``, ``CHAR_SET_CATALOG``,
      ``CHAR_SET_SCHEMA``, ``NUMERIC_PREC_RADIX`` and ``MAX_CARDINALITY``.

  * - ``REFERENTIAL_CONSTRAINTS``
    - ``REF_CONSTRAINTS``
    - ``UNIQUE_CONSTR_CAT``, ``UNIQUE_CONSTR_SCH`` and ``UNIQUE_CONSTR_NAME``.

  * - ``ROUTINES``
    - ``ROUTINES_S``
    - ``CHAR_MAX_LENGTH``, ``CHAR_OCTET_LENGTH``, ``CHAR_SET_CATALOG``,
      ``CHAR_SET_SCHEMA``, ``NUMERIC_PREC_RADIX``, ``MAX_CARDINALITY``,
      ``SCH_LEVEL_ROUTINE``, ``MAX_DYN_RESLT_SETS``, ``IS_USER_DEFND_CAST``,
      ``IS_IMP_INVOCABLE``, ``TO_SQL_SPEC_CAT``, ``TO_SQL_SPEC_SCHEMA``,
      ``TO_SQL_SPEC_NAME``, ``NEW_SAVEPOINT_LVL`` and each column that starts
      with ``RESULT_CAST_``, which starts with ``RC_`` instead (such as
      ``RC_FROM_DATA_TYPE``).

  * - ``SCHEMATA``
    - ``SCHEMATA_S``
    - ``DEF_CHAR_SET_CAT``, ``DEF_CHAR_SET_SCH`` and ``DEF_CHAR_SET_NAME``.

  * - ``SEQUENCES``
    - ``SEQUENCES_S``
    - ``NUMERIC_PREC_RADIX``.

  * - ``SQL_IMPLEMENTATION_INFO``
    - ``SQL_IMPL_INFO``
    - ``IMPL_INFO_ID`` and ``IMPL_INFO_NAME``.

  * - ``SQL_SIZING_PROFILES``
    - ``SQL_SIZING_PROFS``
    - None.

  * - ``TABLES``
    - ``TABLES_S``
    - ``SELF_REF_COL_NAME``, ``REF_GENERATION``, ``UDT_CATALOG``,
      ``UDT_SCHEMA`` and ``UDT_NAME``.

.. code-block:: sql

  SELECT table_name, ref_generation FROM information_schema.tables_s
  WHERE table_schema = 'PUBLIC';
  -- TABLE_NAME: PRODUCTS REF_GENERATION: NULL

The columns are in the same order as the table, so a renamed column replaces
the column with the longer name. Like the other tables of the
``INFORMATION_SCHEMA``, they're described by ``TABLES`` (as a ``VIEW``) and
``COLUMNS``.

The types of the columns of these tables are the domains of the
``INFORMATION_SCHEMA`` in the standard: a name is a ``CHARACTER VARYING(128)``,
other text is a ``CHARACTER VARYING(10485760)``, a number is an ``INTEGER``,
``YES`` or ``NO`` is a ``CHARACTER VARYING(3)`` and a time is a
``TIMESTAMP(2) WITH TIME ZONE``.
