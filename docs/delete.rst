DELETE
======

.. contents::

Syntax
------

.. code-block:: text

  DROP FROM <table_name>
  [ WHERE <expr> ]

If ``WHERE`` is not provided, all records will be deleted.

EXPLAIN
-------

The query planner will decide the best strategy to execute the ``DELETE``. You
can see this plan by using the ``EXPLAIN`` prefix. See :doc:`explain`.
