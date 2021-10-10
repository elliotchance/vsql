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
