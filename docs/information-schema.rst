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
    - The expression of a generated column, otherwise ``NULL``.

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
    - Always ``NONE`` (``MATCH`` is not supported).

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
      standard, such as ``17`` for ``DBMS NAME``.

  * - ``INTEGER_VALUE``, ``CHARACTER_VALUE``
    - The value, which is in one of them (the other one is ``NULL``). The
      ``DBMS VERSION`` is ``00.00.0000`` unless vsql was built for a release,
      when it's followed by the version and its date. The ``DATA SOURCE NAME``
      and ``SERVER NAME`` are the path of the database file (or ``:memory:``).

  * - ``COMMENTS``
    - What the value means.

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

One row for each package of the SQL standard, which is a group of optional
features. A package is only supported when Core SQL (the mandatory features)
and all of its features are, so none of them are yet.

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

  * - ``COLUMNS``
    - ``COLUMNS_S``
    - ``CHAR_MAX_LENGTH``, ``CHAR_OCTET_LENGTH``, ``NUMERIC_PREC_RADIX``,
      ``CHAR_SET_CATALOG``, ``CHAR_SET_SCHEMA``, ``MAX_CARDINALITY``,
      ``IS_SELF_REF``, ``ID_GENERATION``, ``ID_START``, ``ID_INCREMENT``,
      ``ID_MAXIMUM``, ``ID_MINIMUM``, ``ID_CYCLE`` and ``GENERATION_EXPR``.

  * - ``KEY_COLUMN_USAGE``
    - ``KEY_COLUMN_USAGE_S``
    - ``POSITION_IN_UC``.

  * - ``REFERENTIAL_CONSTRAINTS``
    - ``REF_CONSTRAINTS``
    - ``UNIQUE_CONSTR_CAT``, ``UNIQUE_CONSTR_SCH`` and ``UNIQUE_CONSTR_NAME``.

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
other text is a ``CHARACTER VARYING(10485760)``, a number is an ``INTEGER`` and
``YES`` or ``NO`` is a ``CHARACTER VARYING(3)``.
