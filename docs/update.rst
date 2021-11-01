UPDATE
======

.. contents::

Syntax
------

.. code-block:: text

  UPDATE <table_name>
  SET <col> = <value> , ...
  [ WHERE <expr> ]

If ``WHERE`` is not provided, all records will be updated.

The result (eg. ``UPDATE 8``) contains the number of records actually updated.
That is, more than this number of records may have matched, but only those that
were changed will increment this counter.

EXPLAIN
-------

The query planner will decide the best strategy to execute the ``UPDATE``. You
can see this plan by using the ``EXPLAIN`` prefix. See :doc:`explain`.

Errors
------

Only one transaction is allowed to hold a modified version of a record at one
time. This allows all other transactions to see the previous (frozen) version
and the in-flight transaction to see it's own version.

It's not possible for multiple in-flight transactions to hold different versions
of the same semantic row. This would break the serialization rules of the
transaction since this would cause a conflict as to whos version is "correct".
This situation will return a SQLSTATE 40001 "serialization failure" error.
Clients that receive this error should start the entire transaction again.
