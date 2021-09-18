DELETE
======

.. contents::

Syntax
------

.. code-block:: txt

  DROP FROM <table_name>
  [ WHERE <expr> ]

If ``WHERE`` is not provided, all records will be deleted.

EXPLAIN
=======

The query planner will decide the best strategy to execute the ``DELETE``. You
can see this plan by using the ``EXPLAIN`` prefix. See
`EXPLAIN <https://github.com/elliotchance/vsql/blob/main/docs/explain.rst>`_.
