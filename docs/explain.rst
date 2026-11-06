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

An ``INDEX`` (see :doc:`create-index`) is used in the same way, for its columns.
It reads the range of the index, then the row of each entry, in the order of the
index:

.. code-block:: sql

   CREATE INDEX products_price ON products (price);
   EXPLAIN SELECT name FROM products
   WHERE price BETWEEN 10 AND 20;
   -- EXPLAIN: INDEX ":memory:".PUBLIC.PRODUCTS_PRICE ON ":memory:".PUBLIC.PRODUCTS (PRODUCT_ID INTEGER NOT NULL, NAME CHARACTER VARYING(50), PRICE NUMERIC(10, 2)) RANGE PRICE >= 10 AND PRICE <= 20
   -- EXPLAIN: WHERE PRICE BETWEEN 10 AND 20
   -- EXPLAIN: EXPR (NAME CHARACTER VARYING(50))

When the ``PRIMARY KEY`` or more than one index could be used, the one with the
most leading columns compared with ``=`` (and then a range of the next column)
is used. The ``PRIMARY KEY`` is used when they're the same, then the index
that's first by name.

See Also
--------

- :doc:`create-index`
- :doc:`delete`
- :doc:`select`
- :doc:`update`
- :doc:`values`
