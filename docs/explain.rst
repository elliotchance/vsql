EXPLAIN
=======

An ``EXPLAIN`` is not actually a statement, but rather a string prefix that can
be placed before most SQL statements that will cause the query planner to return
the strategy for executing the query without actually running it. This is useful
for debugging query performance.

.. contents::

Syntax
------

.. code-block:: txt

  EXPLAIN ...

Examples
========

.. code-block:: sql

   EXPLAIN SELECT * FROM products
   WHERE product_id >= 123 AND product_id <= 456
   OFFSET 3 ROWS FETCH FIRST 2 ROWS ONLY;

   -- TABLE PRODUCTS OFFSET 3 ROWS
   -- WHERE PRODUCT_ID >= 123 AND PRODUCT_ID <= 456
   -- FETCH FIRST 2 ROWS ONLY

.. code-block:: sql

   EXPLAIN DELETE FROM products
   WHERE product_id = 100;

   -- TABLE PRODUCTS
   -- WHERE PRODUCT_ID = 100

.. code-block:: sql

   EXPLAIN UPDATE products SET price = price * 1.1;

   -- TABLE PRODUCTS
