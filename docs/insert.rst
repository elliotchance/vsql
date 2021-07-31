INSERT
======

.. contents::

Syntax
------

.. code-block:: txt

  INSERT INTO <table_name> ( <col> , ... )
  VALUES ( <value> , ... )

The number of ``col`` and ``value`` must match.

Examples
--------

.. code-block:: sql

  INSERT INTO products (title, price) VALUES ('Instant Pot', 144.89);
