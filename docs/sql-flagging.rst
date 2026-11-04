SQL Flagging
============

An SQL Flagger (ISO/IEC 9075-1, 8.5) finds the SQL that isn't portable, so that
it can be changed before moving to another database. vsql flags the language
that's outside of Core SQL (Feature F812, "Basic flagging"), and also says which
optional feature each one needs ("SQL Feature Flagging").

``features()`` on a prepared statement returns the Feature IDs (see
:doc:`sql-compliance`) that the statement uses, sorted and without duplicates.
A statement that only uses Core SQL returns an empty array:

.. code-block:: v

   mut stmt := db.prepare('SELECT * FROM (VALUES 1) AS t (x) FETCH FIRST 1 ROW ONLY')!
   println(stmt.features()) // ['F591', 'F641', 'F661', 'F857']

   stmt = db.prepare('SELECT name FROM people WHERE age > 20')!
   println(stmt.features()) // []

The statement is only parsed, not executed. The features are found from the
Conformance Rules of ISO/IEC 9075-2 that can be checked from the syntax alone
(the "Syntax Only" extent of checking), so the rules that depend on the data
type of an expression, or on the tables in the catalog, aren't checked. For
example, a ``FOREIGN KEY`` whose columns have different data types than the
columns it references needs T201, but it isn't flagged.

vsql Extensions
---------------

The language that only vsql has is flagged with a Feature ID whose letter is
``V``, which the standard reserves for implementation-defined features. Each
Feature ID is ``VXXX-YY``: ``VXXX`` is a concept (of the standard, such as
tables, or one that only vsql has, such as ``EXPLAIN``) and ``YY`` is each
extension of it.

.. list-table::
   :header-rows: 1

   * - Feature ID
     - Description

   * - ``V001``
     - ``EXPLAIN``.

   * - ``V001-01``
     - ``EXPLAIN`` before a query, such as ``SELECT`` or ``VALUES`` (see
       :doc:`explain`).

   * - ``V001-02``
     - ``EXPLAIN`` before a searched ``DELETE`` (see :doc:`explain`).

   * - ``V001-03``
     - ``EXPLAIN`` before a searched ``UPDATE`` (see :doc:`explain`).

   * - ``V002``
     - Tables.

   * - ``V002-01``
     - ``DROP TABLE`` without ``CASCADE`` or ``RESTRICT`` (it's ``RESTRICT``).

   * - ``V002-02``
     - ``DROP COLUMN`` without ``CASCADE`` or ``RESTRICT`` (it's ``RESTRICT``).

   * - ``V002-03``
     - ``DROP CONSTRAINT`` without ``CASCADE`` or ``RESTRICT`` (it's
       ``RESTRICT``).

   * - ``V003``
     - Sequence generators.

   * - ``V003-01``
     - ``DROP SEQUENCE`` without ``CASCADE`` or ``RESTRICT`` (it's
       ``RESTRICT``).

   * - ``V004``
     - Cursors (see :doc:`cursors`).

   * - ``V004-01``
     - ``DECLARE CURSOR`` outside of an SQL-client module.

   * - ``V004-02``
     - ``OPEN`` outside of an SQL-client module.

   * - ``V004-03``
     - ``FETCH`` without ``INTO`` (the row is returned).

   * - ``V004-04``
     - ``CLOSE`` outside of an SQL-client module.

   * - ``V004-05``
     - ``DELETE ... WHERE CURRENT OF`` outside of an SQL-client module.

   * - ``V004-06``
     - ``UPDATE ... WHERE CURRENT OF`` outside of an SQL-client module.

   * - ``V005``
     - Value functions.

   * - ``V005-01``
     - ``MOD`` with an argument that contains a literal that has a scale or is
       approximate, such as ``MOD(5.5, 2)``. It's only flagged from the syntax,
       so a column of such a type isn't flagged.

   * - ``V005-02``
     - ``TRIM`` with only ``FROM``, such as ``TRIM(FROM x)``.

   * - ``V006``
     - Queries.

   * - ``V006-01``
     - A derived table without a correlation name, such as
       ``SELECT * FROM (VALUES 1)``.

   * - ``V006-02``
     - A sort key that doesn't contain a column reference, such as
       ``ORDER BY 1``.

   * - ``V006-03``
     - A sort key that contains a subquery.

   * - ``V006-04``
     - A sort key that contains an aggregate function.

   * - ``V008``
     - Queries (see :doc:`select`).

   * - ``V008-01``
     - ``SELECT`` without a ``FROM`` clause.

   * - ``V009``
     - Comparison operators (see :doc:`operators`).

   * - ``V009-01``
     - ``!=`` as an alias for ``<>``.
