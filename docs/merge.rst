MERGE
=====

.. contents::

Syntax
------

.. code-block:: text

  MERGE INTO <table_name> [ [ AS ] <correlation_name> ]
  USING <source> ON <condition>
  <when_clause> ...

  <when_clause> ::=
      WHEN MATCHED [ AND <condition> ] THEN UPDATE SET <column_name> = <value> , ...
    | WHEN NOT MATCHED [ AND <condition> ] THEN INSERT [ ( <column_name> , ... ) ]
        [ OVERRIDING { USER | SYSTEM } VALUE ]
        VALUES ( <value> , ... )

``MERGE`` changes a table (the *target*) with the rows of another table or
query (the *source*). Each row of the source is compared with the rows of the
target with the ``ON`` condition:

- A row of the source that matches a row of the target updates it with the
  ``WHEN MATCHED`` clause. The values can reference the columns of the source
  and of the target.
- A row of the source that doesn't match any row of the target is inserted with
  the ``WHEN NOT MATCHED`` clause. The values can only reference the columns of
  the source.

Each clause can have a condition after ``AND``, which can reference the source
and the target (the target is all ``NULL`` for a row that didn't match). The
first clause whose condition is true is used, and a row of the source without
one is left out. A row of the target that's matched by more than one row of the
source only uses the first clause that any of them is for.

The source can be a table, or a query in parentheses with a correlation name
(such as ``(VALUES (1, 'a')) AS s (id, name)``). It can't be a join, and it
can't have the same name as the target.

Every change is worked out before any of them are made, so a row that's
inserted is never matched, and every value sees the table as it was before the
``MERGE``. A row of the target can only be matched by one row of the source
for its clause, otherwise it's an error ``21000`` (cardinality violation) and
nothing is changed.

The rules of each change, such as ``DEFAULT``, generated and identity columns,
``OVERRIDING``, and the constraints of the table, are the same as an
:doc:`update` or an :doc:`insert`.

The result (such as ``MERGE 3``) contains the number of rows that were updated
(including rows that already had the new values) and inserted. If the source
has no rows, the result is ``MERGE 0`` with the completion condition ``02000``
(no data), see :doc:`sqlstate`.

Examples
--------

.. code-block:: sql

  CREATE TABLE stock (id INT PRIMARY KEY, name VARCHAR(10), qty INT);
  INSERT INTO stock (id, name, qty) VALUES (1, 'Coffee', 10), (2, 'Bagel', 20);
  MERGE INTO stock USING (VALUES (2, 'Bagel', 5), (3, 'Tea', 30)) AS s (id, name, qty)
  ON stock.id = s.id
  WHEN MATCHED THEN UPDATE SET qty = stock.qty + s.qty
  WHEN NOT MATCHED THEN INSERT VALUES (s.id, s.name, s.qty);
  SELECT * FROM stock;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: MERGE 2
  -- ID: 1 NAME: Coffee QTY: 10
  -- ID: 2 NAME: Bagel QTY: 25
  -- ID: 3 NAME: Tea QTY: 30

EXPLAIN
-------

The rows of the source are joined with the target (a ``LEFT JOIN``), so when
the ``ON`` condition compares the ``PRIMARY KEY`` (or an index) of the target
with the source, each row of the source finds its row of the target without
reading the whole table. You can see this plan by using the ``EXPLAIN`` prefix.
See :doc:`explain`.

Errors
------

A row that has been changed or deleted by another transaction that hasn't been
committed yet can't be updated. This returns a ``40001`` serialization failure,
see :doc:`transactions`.

See Also
--------

- :doc:`insert`
- :doc:`update`
