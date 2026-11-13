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

The statement isn't executed. Most of the features are found from the Conformance
Rules of ISO/IEC 9075-2 that can be checked from the syntax alone (the "Syntax
Only" extent of checking), and the rules that depend on the data type of an
expression aren't checked.

The rules that depend on what a name refers to are found with the tables in the
catalog when ``features()`` is called (the "Catalog Lookup" extent of checking),
such as the same table in the subquery of a ``DELETE`` (F781), a ``FOREIGN
KEY`` whose columns have different data types than the columns it references
(T201), or a view of the ``INFORMATION_SCHEMA`` (or one of its columns) that
needs a feature, such as ``KEY_COLUMN_USAGE`` (F341) or ``COLUMNS.IS_UPDATABLE``
(T111). These names are only resolved in a query, a cursor, a ``DELETE``, an
``INSERT`` from a query, an ``UPDATE``, a ``CREATE TABLE`` or an ``ALTER
TABLE``. Nothing is flagged for a
name that can't be resolved yet, such as for a table that doesn't exist, or
anything after a dynamic parameter (which doesn't have a value yet).

SQL-client Modules, Embedded SQL and Direct SQL
-----------------------------------------------

The language that can't be prepared has the same flagging, and is only compiled
or parsed:

.. code-block:: v

   m := vsql.compile_module(source, 'name')!
   println(m.features) // ['B031', 'B112']

   p := vsql.precompile_c(source, 'program.sqc')!
   println(p.features) // ['B012']

   println(vsql.direct_features('SELECT CURRENT_SCHEMA FROM t;')!) // ['B021', 'F763']

``features`` of a ``CompiledModule`` and of a
``PrecompiledProgram`` are found from everything in the source, which includes
the features of each statement, cursor and host parameter data type.

``direct_features`` is for a statement of ``Connection.direct`` and
``Agent.direct``, which has the same errors if it isn't one statement that ends
with a semicolon, or if it has a parameter. Unlike those, it doesn't execute the
statement, so it doesn't need a connection.

The SQL given to ``PREPARE`` or ``EXECUTE IMMEDIATE`` isn't flagged, since it's
usually not known until the module is executed.

vsql Extensions
---------------

The language that only vsql has is flagged with a Feature ID whose letter is
``V``, which the standard reserves for implementation-defined features. Each
Feature ID is ``VXXX-YY``: ``VXXX`` is what's extended and ``YY`` is each extension
of it. The first digit of ``VXXX`` is the kind of thing that's extended:

- ``V0XX``: A statement that isn't in the standard, such as ``EXPLAIN``.
- ``V1XX``: A statement of the standard, other than a query, such as
  ``DROP TABLE``. An alias of a statement is an extension of that statement.
- ``V2XX``: A query, by its clause, such as ``ORDER BY``.
- ``V3XX``: An operator or predicate.
- ``V4XX``: A function, by its category in :doc:`functions`.

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

   * - ``V001-04``
     - ``EXPLAIN`` before a ``MERGE`` (see :doc:`explain`).

   * - ``V002``
     - ``CREATE INDEX``.

   * - ``V002-01``
     - ``CREATE INDEX`` (see :doc:`create-index`).

   * - ``V002-02``
     - ``CREATE UNIQUE INDEX`` (see :doc:`create-index`).

   * - ``V002-03``
     - ``CREATE INDEX IF NOT EXISTS`` (see :doc:`create-index`).

   * - ``V003``
     - ``DROP INDEX``.

   * - ``V003-01``
     - ``DROP INDEX`` (see :doc:`drop-index`).

   * - ``V003-02``
     - ``DROP INDEX IF EXISTS`` (see :doc:`drop-index`).

   * - ``V101``
     - ``CREATE SCHEMA``.

   * - ``V101-01``
     - ``CREATE SCHEMA IF NOT EXISTS`` (see :doc:`create-schema`).

   * - ``V102``
     - ``DROP SCHEMA``.

   * - ``V102-01``
     - ``DROP SCHEMA IF EXISTS`` (see :doc:`drop-schema`).

   * - ``V103``
     - ``CREATE TABLE``.

   * - ``V103-01``
     - ``CREATE TABLE IF NOT EXISTS`` (see :doc:`create-table`).

   * - ``V104``
     - ``DROP TABLE``.

   * - ``V104-01``
     - ``DROP TABLE`` without ``CASCADE`` or ``RESTRICT`` (it's ``RESTRICT``).

   * - ``V104-02``
     - ``DROP TABLE IF EXISTS`` (see :doc:`drop-table`).

   * - ``V105``
     - ``ALTER TABLE``.

   * - ``V105-01``
     - ``DROP COLUMN`` without ``CASCADE`` or ``RESTRICT`` (it's ``RESTRICT``).

   * - ``V105-02``
     - ``DROP CONSTRAINT`` without ``CASCADE`` or ``RESTRICT`` (it's
       ``RESTRICT``).

   * - ``V106``
     - ``CREATE SEQUENCE``.

   * - ``V106-01``
     - ``CREATE SEQUENCE IF NOT EXISTS`` (see :doc:`create-sequence`).

   * - ``V107``
     - ``DROP SEQUENCE``.

   * - ``V107-01``
     - ``DROP SEQUENCE`` without ``CASCADE`` or ``RESTRICT`` (it's
       ``RESTRICT``).

   * - ``V107-02``
     - ``DROP SEQUENCE IF EXISTS`` (see :doc:`drop-sequence`).

   * - ``V108``
     - ``DECLARE CURSOR`` (see :doc:`cursors`).

   * - ``V108-01``
     - ``DECLARE CURSOR`` outside of an SQL-client module.

   * - ``V109``
     - ``OPEN`` (see :doc:`cursors`).

   * - ``V109-01``
     - ``OPEN`` outside of an SQL-client module.

   * - ``V110``
     - ``FETCH`` (see :doc:`cursors`).

   * - ``V110-01``
     - ``FETCH`` without ``INTO`` (the row is returned).

   * - ``V111``
     - ``CLOSE`` (see :doc:`cursors`).

   * - ``V111-01``
     - ``CLOSE`` outside of an SQL-client module.

   * - ``V112``
     - ``DELETE`` (see :doc:`cursors`).

   * - ``V112-01``
     - ``DELETE ... WHERE CURRENT OF`` outside of an SQL-client module.

   * - ``V113``
     - ``UPDATE`` (see :doc:`cursors`).

   * - ``V113-01``
     - ``UPDATE ... WHERE CURRENT OF`` outside of an SQL-client module.

   * - ``V114``
     - ``START TRANSACTION`` (see :doc:`start-transaction`).

   * - ``V114-01``
     - ``BEGIN`` instead of ``START TRANSACTION``.

   * - ``V115``
     - ``COMMIT`` (see :doc:`commit`).

   * - ``V115-01``
     - ``COMMIT TRANSACTION`` instead of ``COMMIT``.

   * - ``V115-02``
     - ``END`` instead of ``COMMIT``.

   * - ``V116``
     - ``ROLLBACK`` (see :doc:`rollback`).

   * - ``V116-01``
     - ``ROLLBACK TRANSACTION`` instead of ``ROLLBACK``.

   * - ``V116-02``
     - ``ABORT`` instead of ``ROLLBACK``.

   * - ``V117``
     - ``PREPARE`` (see :doc:`prepared-statements`).

   * - ``V117-01``
     - ``PREPARE`` from a literal, rather than a host parameter.

   * - ``V118``
     - ``EXECUTE IMMEDIATE``.

   * - ``V118-01``
     - ``EXECUTE IMMEDIATE`` of a literal, rather than a host parameter.

   * - ``V201``
     - ``FROM``.

   * - ``V201-01``
     - ``SELECT`` without a ``FROM`` clause (see :doc:`select`).

   * - ``V201-02``
     - A derived table without a correlation name, such as
       ``SELECT * FROM (VALUES 1)``.

   * - ``V202``
     - ``ORDER BY``.

   * - ``V202-01``
     - A sort key that doesn't contain a column reference, such as
       ``ORDER BY 1``.

   * - ``V202-02``
     - A sort key that contains a subquery.

   * - ``V202-03``
     - A sort key that contains an aggregate function.

   * - ``V203``
     - ``LIMIT`` (see :doc:`select`).

   * - ``V203-01``
     - ``LIMIT`` instead of ``FETCH FIRST``.

   * - ``V203-02``
     - ``OFFSET`` without ``ROW`` or ``ROWS``.

   * - ``V203-03``
     - ``LIMIT <offset>, <count>``.

   * - ``V301``
     - Comparison operators (see :doc:`operators`).

   * - ``V301-01``
     - ``!=`` as an alias for ``<>``.

   * - ``V302``
     - ``ILIKE`` (see :doc:`expressions`).

   * - ``V302-01``
     - ``ILIKE`` and ``NOT ILIKE`` (a case-insensitive ``LIKE``).

   * - ``V402``
     - Date and time functions (see :doc:`dates-times`).

   * - ``V402-01``
     - ``NOW()`` instead of ``CURRENT_TIMESTAMP``.

   * - ``V403``
     - Mathematical functions: the arithmetic, exponent and logarithm, rounding
       and trigonometric functions (see :doc:`functions`).

   * - ``V403-01``
     - ``MOD`` with an argument that contains a literal that has a scale or is
       approximate, such as ``MOD(5.5, 2)``. It's only flagged from the syntax,
       so a column of such a type isn't flagged.

   * - ``V404``
     - String functions (see :doc:`functions`).

   * - ``V404-01``
     - ``TRIM`` with only ``FROM``, such as ``TRIM(FROM x)``.
