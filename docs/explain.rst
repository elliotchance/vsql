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

A ``PRIMARY KEY`` only reads the rows in a range of the key. It's used when
the ``WHERE`` clause compares columns of the key with a value that's the same for
every row (such as ``=``, ``<``, ``>=`` or ``BETWEEN``), and those comparisons are
joined by ``AND``. With a ``PRIMARY KEY`` of more than one column, the columns
compared with ``=`` must be the first ones, then the next column can have a range.
The ``WHERE`` clause is still applied to each row that's read:

.. code-block:: sql

   EXPLAIN DELETE FROM products
   WHERE product_id >= 100 AND product_id < 200 AND price > 10;
   -- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.PRODUCTS (PRODUCT_ID INTEGER NOT NULL, NAME CHARACTER VARYING(50), PRICE NUMERIC(10, 2)) RANGE PRODUCT_ID >= 100 AND PRODUCT_ID < 200
   -- EXPLAIN: WHERE PRODUCT_ID >= 100 AND PRODUCT_ID < 200 AND PRICE > 10

See Also
--------

- :doc:`delete`
- :doc:`select`
- :doc:`update`
- :doc:`values`
