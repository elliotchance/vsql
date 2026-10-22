DELETE
======

.. contents::

Syntax
------

.. code-block:: text

  DELETE FROM <table_name>
  [ WHERE <condition> ]

Deletes the rows of a table that match the ``WHERE`` condition. If ``WHERE`` is
not provided, all rows will be deleted.

The result (such as ``DELETE 3``) contains the number of rows deleted.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price FLOAT);
  INSERT INTO products (name, price) VALUES ('Coffee', 4.5e0), ('Bagel', 2.25e0);
  DELETE FROM products WHERE price < 3e0;
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: DELETE 1
  -- NAME: Coffee PRICE: 4.5e0

EXPLAIN
-------

The query planner will decide the best strategy to execute the ``DELETE``. You
can see this plan by using the ``EXPLAIN`` prefix. See :doc:`explain`.

Errors
------

A row that has been changed or deleted by another transaction that hasn't been
committed yet can't be deleted. This returns a ``40001`` serialization failure,
see :doc:`transactions`.

See Also
--------

- :doc:`insert`
- :doc:`update`
