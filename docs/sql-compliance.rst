SQL Compliance
==============

.. contents::

vsql aims to be SQL compliant by following the 2016 SQL Standard in both BNF
syntax and mandatory features.

There are still many features to be implemented before it can be considered
fully compliant - as shown by the Mandatory Features table below.

Mandatory Features
------------------

The following table is **not complete** and will be filled in as time goes on.

.. list-table:: Table 43 — Feature taxonomy and definition for mandatory features
   :header-rows: 1

   * - Feature ID
     - Supported
     - Feature Name

   * - **E011**
     - **Partial**
     - **Numeric data types**

   * - E011-01
     - Yes
     - ``INTEGER`` and ``SMALLINT`` data types (including all spellings)

   * - E011-02
     - Yes
     - ``REAL``, ``DOUBLE PRECISON``, and ``FLOAT`` data types

   * - E011-03
     - No
     - ``DECIMAL`` and ``NUMERIC`` data types

   * - E011-04
     - Yes
     - Arithmetic operators

   * - E011-05
     - Yes
     - Numeric comparison

   * - E011-06
     - No
     - Implicit casting among the numeric data types

   * - **E021**
     - **Partial**
     - **Character string types**

   * - E021-01
     - Yes
     - ``CHARACTER`` data type (including all its spellings)

   * - E021-02
     - Yes
     - ``CHARACTER VARYING`` data type (including all its spellings)

   * - E021-03
     - Yes
     - Character literals

   * - E021-04
     - Yes
     - ``CHARACTER_LENGTH`` function

   * - E021-05
     - Yes
     - ``OCTET_LENGTH`` function

   * - E021-06
     - No
     - ``SUBSTRING`` function

   * - E021-07
     - Yes
     - Character concatenation

   * - E021-08
     - Yes
     - ``UPPER`` and ``LOWER`` functions

   * - E021-09
     - No
     - ``TRIM`` function

   * - E021-10
     - No
     - Implicit casting among the fixed-length and variable-length character string types

   * - E021-11
     - Yes
     - ``POSITION`` function

   * - E021-12
     - Partial
     - Character comparison

   * - **E031**
     - **Unknown**
     - **Identifiers**

   * - **E051**
     - **Unknown**
     - **Basic query specification**

   * - **E061**
     - **Unknown**
     - **Basic predicates and search conditions**

   * - **E071**
     - **Unknown**
     - **Basic query expressions**

   * - **E081**
     - **Unknown**
     - **Basic Privileges**

   * - **E091**
     - **Unknown**
     - **Set functions**

   * - **E071**
     - **Unknown**
     - **Basic query expressions**

   * - **E101**
     - **Unknown**
     - **Basic data manipulation**

   * - **E111**
     - **Unknown**
     - **Single row SELECT statement**

   * - **E121**
     - **Unknown**
     - **Basic cursor support**

   * - **E131**
     - **Unknown**
     - **Null value support (nulls in lieu of values)**

   * - **E141**
     - **Unknown**
     - **Basic integrity constraints**

   * - **E151**
     - **Unknown**
     - **Transaction support**

   * - **E152**
     - **Unknown**
     - **Basic SET TRANSACTION statement**

   * - **E153**
     - **Unknown**
     - **Updatable queries with subqueries**

   * - **E161**
     - **Unknown**
     - **SQL comments using leading double minus**

   * - **E171**
     - **Unknown**
     - **SQLSTATE support**

   * - **E182**
     - **Unknown**
     - **Host language binding**

   * - **F031**
     - **Unknown**
     - **Basic schema manipulation**

   * - **F041**
     - **Partial**
     - **Basic joined table**

   * - F041-01
     - Yes
     - Inner join (but not necessarily the ``INNER`` keyword)

   * - F041-02
     - Yes
     - ``INNER`` keyword

   * - F041-03
     - Yes
     - ``LEFT OUTER JOIN``

   * - F041-04
     - Yes
     - ``RIGHT OUTER JOIN``

   * - F041-05
     - No
     - Outer joins can be nested

   * - F041-07
     - No
     - The inner table in a left or right outer join can also be used in an inner join

   * - F041-08
     - Yes
     - All comparison operators are supported (rather than just =)

   * - **F051**
     - **Partial**
     - **Basic date and time**

   * - F051-01
     - Yes
     - ``DATE`` data type (including support of ``DATE`` literal)

   * - F051-02
     - Yes
     - ``TIME`` data type (including support of ``TIME`` literal) with fractional seconds precision of at least 0.

   * - F051-03
     - Yes
     - ``TIMESTAMP`` data type (including support of ``TIMESTAMP`` literal) with fractional seconds precision of at least 0 and 6.

   * - F051-04
     - No
     - Comparison predicate on ``DATE``, ``TIME``, and ``TIMESTAMP`` data types

   * - F051-05
     - No
     - Explicit ``CAST`` between date-time types and character string types

   * - F051-06
     - Yes
     - ``CURRENT_DATE``

   * - F051-07
     - Yes
     - ``LOCALTIME``

   * - F051-08
     - Yes
     - ``LOCALTIMESTAMP``

   * - **F081**
     - **Unknown**
     - **UNION and EXCEPT in views**

   * - **F131**
     - **Unknown**
     - **Grouped operations**

   * - **F181**
     - **Unknown**
     - **Multiple module support**

   * - **F201**
     - **Unknown**
     - **CAST function**

   * - **F221**
     - **Unknown**
     - **Explicit defaults**

   * - **F261**
     - **Unknown**
     - **CASE expression**

   * - **F311**
     - **Partial**
     - **Schema definition statement**

   * - F311-01
     - Yes
     - ``CREATE SCHEMA``

   * - F311-02
     - Yes
     - ``CREATE TABLE`` for persistent base tables

   * - F311-03
     - No
     - ``CREATE VIEW``

   * - F311-04
     - No
     - ``CREATE VIEW``: ``WITH CHECK OPTION``

   * - F311-05
     - No
     - ``GRANT`` statement

   * - **F471**
     - **Unknown**
     - **Scalar subquery values**

   * - **F481**
     - **Unknown**
     - **Expanded NULL predicate**

   * - **F812**
     - **Unknown**
     - **Basic flagging**

   * - **S011**
     - **Unknown**
     - **Distinct data types**

   * - **T321**
     - **Unknown**
     - **Basic SQL-invoked routines**

   * - **T631**
     - **Unknown**
     - **IN predicate with one list element**

Optional Features
-----------------

The following table has not been filled in. It is here as a placeholder.

.. list-table:: Table 44 — Feature taxonomy for optional features
   :header-rows: 1

   * - Feature ID
     - Supported
     - Feature Name

   * - **B011**
     - No
     - **Embedded Ada**

See Also
--------

- https://en.wikipedia.org/wiki/SQL_compliance
