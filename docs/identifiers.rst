Identifiers and Names
=====================

.. contents::

An identifier is the name of something, such as a table, column, schema,
sequence, cursor or correlation name (``AS`` name). There are two kinds:
*regular* identifiers (such as ``products``) and *delimited* identifiers, which
are in double quotes (such as ``"Products"``).

Regular Identifiers
-------------------

A regular identifier starts with a letter or an underscore, followed by any
number of letters, digits and underscores. Only the ASCII letters ``A`` to ``Z``
(in either case) can be used, so ``café`` is a syntax error unless it's quoted.

A regular identifier is converted to upper case. So ``products``, ``Products``
and ``PRODUCTS`` are all the same name, which is ``PRODUCTS``, and that's how it
appears in results, error messages and the :doc:`information-schema`:

.. code-block:: sql

  CREATE TABLE Products (Name VARCHAR(20));
  INSERT INTO products (name) VALUES ('Apple');
  SELECT NAME FROM PRODUCTS;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- NAME: Apple

This is what the SQL standard requires. Some other databases (such as
PostgreSQL) convert to lower case instead, which only makes a difference when a
name is used both with and without quotes.

A regular identifier can't be a reserved word, such as ``ORDER`` or ``VALUE``.
The reserved words are listed in :doc:`keywords`, and the error says when a name
is one:

.. code-block:: sql

  CREATE TABLE order (x INT);
  -- error 42601: syntax error: unexpected ORDER at line 1, column 14 near "CREATE TABLE order ("; hint: ORDER is a reserved word, so it must be quoted to be used as a name, such as "ORDER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

Delimited Identifiers
---------------------

A delimited identifier is in double quotes and keeps its case, so ``"Price"``
and ``"PRICE"`` are different names. It can contain any character (including
spaces, punctuation and non-ASCII letters), except for control and format
characters (such as a tab or a zero width space), unassigned code points, and
line and paragraph separators (the Unicode General Categories Cc, Cf, Cn, Cs,
Zl and Zp). A double quote is written twice, so ``"say ""hi"""`` is the name
``say "hi"``. It can't be empty (``""``).

A delimited identifier can be a reserved word, such as ``"ORDER"``, and it's
the only way to have a name that isn't upper case:

.. code-block:: sql

  SELECT 1 + 2 AS "the Total" FROM (VALUES 1) AS t;
  -- the Total: 3

Regular and delimited identifiers are the same kind of name, a regular
identifier is just converted to upper case first. So ``"PRODUCTS"`` is the same
as ``products``, but ``"products"`` is not:

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(20));
  INSERT INTO products (name) VALUES ('Apple');
  SELECT "NAME" FROM "PRODUCTS";
  SELECT "name" FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- NAME: Apple
  -- error 42601: syntax error: unknown column: ":memory:".PUBLIC."name"

Names that aren't upper case are shown in double quotes in error messages, such
as ``"name"`` above.

The SQL standard also has Unicode delimited identifiers (such as
``U&"caf\00e9"``), but vsql doesn't support them yet. Use the character itself
in a delimited identifier instead, such as ``"café"``.

Length
------

A name can have up to 128 characters, whether it's quoted or not. A longer name
is a ``42601`` error.

Qualified Names
---------------

Every table, view and sequence is in a schema, and every schema is in a
catalog. A catalog is a database file (see :doc:`set-catalog`). A name can be
*qualified* with its schema, or with its catalog and schema, by separating the
parts with a ``.``:

.. code-block:: text

  name
  schema.name
  catalog.schema.name

Each part is an identifier on its own, so each one can be regular or delimited,
such as ``"my db".public.products``. A name can't have more than three parts.

A column can be qualified with the table (or correlation name) that it's from,
and the table name can itself be qualified, such as ``products.name`` or
``public.products.name``.

Name Resolution
---------------

A name that doesn't have a catalog is in the current catalog, and a name that
doesn't have a schema is in the current schema. A connection starts with the
catalog of the file that it opened and the ``PUBLIC`` schema, which every
database file has. They can be changed with :doc:`set-catalog` and
:doc:`set-schema`, and ``CURRENT_CATALOG`` and ``CURRENT_SCHEMA`` give the
current values:

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(20));
  INSERT INTO products (name) VALUES ('Apple');
  CREATE SCHEMA store;
  CREATE TABLE store.products (name VARCHAR(20));
  INSERT INTO store.products (name) VALUES ('Banana');
  SET SCHEMA 'store';
  SELECT name FROM products;
  SELECT name FROM public.products;
  VALUES CURRENT_SCHEMA;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: CREATE SCHEMA 1
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: SET SCHEMA 1
  -- NAME: Banana
  -- NAME: Apple
  -- COL1: STORE

A schema or catalog that doesn't exist is an error (``3F000`` or ``3D000``),
and a table that doesn't exist is ``42P01``.

An unqualified column name is looked for in the tables of the ``FROM`` clause.
If more than one of them has a column with that name, the name is ambiguous and
it has to be qualified (such as ``a.id``):

.. code-block:: sql

  CREATE TABLE a (id INT);
  CREATE TABLE b (id INT);
  SELECT id FROM a, b;
  -- msg: CREATE TABLE 1
  -- msg: CREATE TABLE 1
  -- error 42702: ambiguous column: ID

When a table has a correlation name (``AS``), a column can only be qualified
with the correlation name, not the table name. In a subquery, a name is looked
for in the subquery's own tables first, and then in the tables of the queries
around it (see :ref:`expressions:Correlated Subqueries`).

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(20));
  SELECT products.name FROM products AS p;
  -- msg: CREATE TABLE 1
  -- error 42601: syntax error: unknown column: ":memory:".PUBLIC.PRODUCTS.NAME
