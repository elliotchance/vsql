EXPLAIN
=======

``EXPLAIN`` can be placed before a ``SELECT``, ``VALUES``, ``UPDATE`` or
``DELETE`` to return the plan that the query planner chose, without running
the statement. This is useful for debugging query performance.

.. contents::

Syntax
------

.. code-block:: text

  EXPLAIN <statement>

Each line of the plan is a row with a single ``EXPLAIN`` column. The format of
the plan is meant for people to read, and may change between versions.

Examples
--------

These examples use this table:

.. code-block:: sql

   CREATE TABLE products (
     product_id INT NOT NULL,
     name VARCHAR(50),
     price NUMERIC(10, 2),
     PRIMARY KEY (product_id)
   );

A ``TABLE`` reads every row of the table:

.. code-block:: sql

   EXPLAIN SELECT name FROM products
   WHERE price > 10
   ORDER BY name
   FETCH FIRST 2 ROWS ONLY;
   -- EXPLAIN: TABLE ":memory:".PUBLIC.PRODUCTS (PRODUCT_ID INTEGER NOT NULL, NAME CHARACTER VARYING(50), PRICE NUMERIC(10, 2))
   -- EXPLAIN: WHERE PRICE > 10
   -- EXPLAIN: ORDER BY NAME ASC
   -- EXPLAIN: FETCH FIRST 2 ROWS ONLY
   -- EXPLAIN: EXPR (NAME CHARACTER VARYING(50))

Comparing the ``PRIMARY KEY`` with ``=`` only reads the matching row:

.. code-block:: sql

   EXPLAIN DELETE FROM products
   WHERE product_id = 100;
   -- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.PRODUCTS (PRODUCT_ID INTEGER NOT NULL, NAME CHARACTER VARYING(50), PRICE NUMERIC(10, 2)) BETWEEN 100 AND 100

See Also
--------

- :doc:`delete`
- :doc:`select`
- :doc:`update`
- :doc:`values`
