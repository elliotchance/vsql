CREATE VIEW
===========

.. contents::

Syntax
------

.. code-block:: text

  CREATE VIEW <view_name> [ ( <column_name> , ... ) ] AS <query>

Creates a view, which is a table whose rows are the result of a query. The
query can be any query, such as a ``SELECT`` (including joins, subqueries,
``GROUP BY``, ``ORDER BY``, ``OFFSET`` and ``FETCH FIRST``), ``VALUES``, or a
``UNION``, ``EXCEPT`` or ``INTERSECT`` of them. A view can be read anywhere a
table can, including by the query of another view. The rows aren't stored:
the query runs each time the view is read, so a view always has the current
rows of the tables that it reads.

A view has the same name as a table would, and it can't have the same name as
any other table or view in its schema (``42P07``).

Columns
-------

The columns of the view are the columns of the query, with the same data
types. They're named by the column list, if there is one, which must have a
name for each column of the query. Otherwise they have the names of the
columns of the query, and the column list is needed when two columns have the
same name, or when a column has no name (such as ``SELECT a * 2``, without an
``AS``).

An asterisk (such as ``SELECT *`` or ``SELECT t.*``) is the columns that it is
when the view is created. A column that's added to a table later (see
:doc:`alter-table`) isn't added to the view.

Names
-----

A name in the query without a schema is in the current schema when the view is
created (see :doc:`set-schema`), or the new schema in a :doc:`create-schema`.
That's kept with the view, so a view that reads ``t`` while the current schema
is ``S`` always reads ``S.t``, whatever the current schema is when the view is
read, and even if the view itself is in another schema.

A view can only read the tables (and views) of its own catalog.

Restrictions
------------

- A view can't be changed yet: ``INSERT``, ``UPDATE`` and ``DELETE`` can't be
  used on a view, and a cursor that reads a view can't be ``FOR UPDATE``.
- ``WITH CHECK OPTION`` and ``RECURSIVE`` views aren't supported.
- The query can't contain parameters, or ``NEXT VALUE FOR``.

Dependencies
------------

A view depends on everything its query reads. A table, view or column that a
view depends on can only be dropped with ``CASCADE``, which also drops the view
(see :doc:`drop-table`, :doc:`drop-view`, :doc:`drop-schema` and
:doc:`alter-table`).

File Format
-----------

The first ``CREATE VIEW`` in a file changes the file so that a version of vsql
from before views can still read it, but not change it (see "Compatibility" in
:doc:`file-format`).

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price DECIMAL(10, 2));
  INSERT INTO products (name, price) VALUES ('Apple', 1.25), ('Pear', 2.5);
  CREATE VIEW cheap_products AS SELECT name FROM products WHERE price < 2;
  SELECT * FROM cheap_products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: CREATE VIEW 1
  -- NAME: Apple

.. code-block:: sql

  CREATE VIEW price_list (product, cents) AS
    SELECT name, price * 100 FROM products;

See Also
--------

- :doc:`drop-view`
- :doc:`information-schema`
- :doc:`select`
