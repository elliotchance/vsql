DELETE
======

.. contents::

Syntax
------

.. code-block:: text

  DELETE FROM <table_name> [ [ AS ] <correlation_name> ]
  [ WHERE <condition> ]
  [ RETURNING { * | <expression> [ AS <name> ] } , ... ]

Deletes the rows of a table that match the ``WHERE`` condition. If ``WHERE`` is
not provided, all rows will be deleted.

``AS <correlation_name>`` gives the table a *correlation name*. The table must
then be referred to by that name instead (such as ``p.price``), which is useful
when a subquery reads the same table.

The result (such as ``DELETE 3``) contains the number of rows deleted. If no
rows are deleted, the result is ``DELETE 0`` with the completion condition
``02000`` (no data), see :doc:`sqlstate`.

With ``RETURNING``, the result is each deleted row (as it was) instead, like
``SELECT ... FROM OLD TABLE (DELETE ...)`` (see :doc:`select`). A column can be
qualified with the correlation name, or the name of the table if there isn't
one. It isn't standard SQL, so it's flagged as ``V112-02`` (see :doc:`insert`
and :doc:`sql-flagging`).

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
