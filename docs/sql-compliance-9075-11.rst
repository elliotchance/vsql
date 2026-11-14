ISO/IEC 9075-11:2006 (Information and Definition Schemas)
=========================================================

.. contents::

This page is for **ISO/IEC 9075-11:2006(E)** (the SQL:2008 committee draft,
2006-02), which is the edition of this part that vsql is pinned to (see
:doc:`standard-index`). The feature IDs, feature names, table numbers and
Subclause numbers on this page are all from that edition, and can be different
in other editions.

Part 11 defines the ``INFORMATION_SCHEMA`` (see :doc:`information-schema`), a
set of read-only tables that describe the schemas, tables and other objects in
a database. The features
below are the ones that Part 11 adds to, or extends from, Part 2.

The short name views (5.77) of the views that vsql has (``COLUMNS_S``,
``KEY_COLUMN_USAGE_S``, ``REF_CONSTRAINTS`` and ``TABLES_S``) are there too.
They aren't a feature of their own.

Mandatory Features
------------------

As of the latest version (or at least the version of this documentation)
**vsql supports 8 of the 15 mandatory features** of ISO/IEC 9075-11:2006.

.. list-table:: Table 2 — Feature taxonomy and definition for mandatory features
   :header-rows: 1

   * - Feature ID
     - Feature Name

   * - ⭕ **F021**
     - **Basic information schema**

   * - ✅ F021-01
     - ``COLUMNS`` view

   * - ✅ F021-02
     - ``TABLES`` view

   * - ❌ F021-03
     - ``VIEWS`` view

   * - ✅ F021-04
     - ``TABLE_CONSTRAINTS`` view

   * - ✅ F021-05
     - ``REFERENTIAL_CONSTRAINTS`` view

   * - ✅ F021-06
     - ``CHECK_CONSTRAINTS`` view

   * - ✅ **F501**
     - **Features and conformance views**

   * - ✅ F501-01
     - ``SQL_FEATURES`` view

   * - ✅ F501-02
     - ``SQL_SIZING`` view

   * - ❌ **S011**
     - **Distinct data types**

   * - ❌ S011-01
     - ``USER_DEFINED_TYPES`` view

   * - ❌ **T321**
     - **Basic SQL-invoked routines**

   * - ❌ T321-06
     - ``ROUTINES`` view

   * - ❌ T321-07
     - ``PARAMETERS`` view

Optional Features
-----------------

The optional features in Part 11 are the ``INFORMATION_SCHEMA`` parts of
features in Part 2. A feature that's supported in Part 2 may not be supported
here.

.. list-table:: Table 3 — Feature taxonomy for optional features
   :header-rows: 1

   * - Feature ID
     - Feature Name

   * - ❌ **F231**
     - **Privilege tables**

   * - ❌ **F251**
     - **Domain support**

   * - ⭕ **F341**
     - **Usage tables**

   * - ⭕ **F391**
     - **Long identifiers**

   * - ✅ **F502**
     - **Enhanced documentation tables**

   * - ❌ **F521**
     - **Assertions**

   * - ❌ **F651**
     - **Catalog name qualifiers**

   * - ❌ **F690**
     - **Collation support**

   * - ❌ **F695**
     - **Translation support**

   * - ❌ **F696**
     - **Additional translation documentation**

   * - ❌ **S023**
     - **Basic structured types**

   * - ❌ **S024**
     - **Enhanced structured types**

   * - ❌ **S041**
     - **Basic reference types**

   * - ❌ **S081**
     - **Subtables**

   * - ❌ **S091**
     - **Basic array support**

   * - ❌ **S241**
     - **Transform functions**

   * - ❌ **S271**
     - **Basic multiset support**

   * - ❌ **T011**
     - **Timestamp in Information Schema**

   * - ❌ **T051**
     - **Row types**

   * - ⭕ **T175**
     - **Generated columns**

   * - ❌ **T176**
     - **Sequence generator support**

   * - ❌ **T211**
     - **Basic trigger capability**

   * - ❌ **T272**
     - **Enhanced savepoint management**

   * - ❌ **T331**
     - **Basic roles**

See Also
--------

- :doc:`sql-compliance` for the other parts.
- `ISO/IEC 9075-11 - Information technology — Database languages — SQL — Part 11: Information and Definition Schemas (SQL/Schemata) <https://www.iso.org/standard/63565.html>`_ (the 2016 edition, which is newer than the edition used here)
