UPDATE
======

.. contents::

Syntax
------

.. code-block:: text

  UPDATE <table_name>
  SET <column_name> = <value> , ...
  [ WHERE <condition> ]

If ``WHERE`` is not provided, all records will be updated.

A value can be ``DEFAULT``, which is the default value of the column (see
:doc:`create-table`).

A changed row that violates a ``CHECK`` constraint is an error ``23514``, and
none of the rows are updated.

The result (such as ``UPDATE 8``) contains the number of records matched,
including records that already had the new values. If no records are matched,
the result is ``UPDATE 0`` with the completion condition ``02000`` (no data),
see :doc:`sqlstate`.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);
  UPDATE products SET price = price * 2 WHERE name = 'Bagel';
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: UPDATE 1
  -- NAME: Coffee PRICE: 4.50
  -- NAME: Bagel PRICE: 4.50

EXPLAIN
-------

The query planner will decide the best strategy to execute the ``UPDATE``. You
can see this plan by using the ``EXPLAIN`` prefix. See :doc:`explain`.

Errors
------

Only one transaction is allowed to hold a modified version of a record at one
time. This allows all other transactions to see the previous (frozen) version
and the in-flight transaction to see its own version.

It's not possible for multiple in-flight transactions to hold different versions
of the same semantic row. This would break the serialization rules of the
transaction since this would cause a conflict as to whose version is "correct".
This situation will return a SQLSTATE 40001 "serialization failure" error, and
the transaction is rolled back. Clients that receive this error should start
the entire transaction again.
