CREATE SEQUENCE
===============

.. contents::

Syntax
------

.. code-block:: text

  CREATE SEQUENCE <sequence_name> [ <option> ... ]

A sequence is used as an atomic counter. It is useful for generating unique and
sequential numbers.

A sequence can have a minimum and maximum value, and can be allowed to cycle
(wrap around) between them.

Options
-------

Each ``<option>`` can be one of (in any order):

.. code-block:: text

   START WITH <number>
   INCREMENT BY <number>
   MINVALUE <number>
   NO MINVALUE
   MAXVALUE <number>
   NO MAXVALUE
   CYCLE
   NO CYCLE

A sequence starts at the ``MINVALUE`` (or ``MAXVALUE`` for a sequence with a
negative ``INCREMENT BY``) unless ``START WITH`` is provided, and it doesn't
cycle unless ``CYCLE`` is provided.

The values of a sequence are ``BIGINT``.

``NEXT VALUE FOR`` can't be used in a ``WHERE``, a ``HAVING``, a join
condition, an ``ORDER BY``, an aggregate function or a grouped query (a
``GROUP BY``, a ``HAVING`` or an aggregate function in the select list), since
the value would depend on how many times the expression is evaluated.

Examples
--------

The simplest case is to create a sequence with no options. By default a sequence
will start at 1 and increment by 1:

.. code-block:: sql

  CREATE SEQUENCE seq1;
  VALUES NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1;
  -- msg: CREATE SEQUENCE 1
  -- COL1: 1
  -- COL1: 2

A sequence will return an error if it tries to go beyond the allowed limits:

.. code-block:: sql

  CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20;
  VALUES NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1;
  -- msg: CREATE SEQUENCE 1
  -- COL1: 10
  -- COL1: 15
  -- COL1: 20
  -- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

However, we can use ``CYCLE`` to allow the sequence to wrap around:

.. code-block:: sql

  CREATE SEQUENCE seq1 MINVALUE 10 INCREMENT BY 5 MAXVALUE 20 CYCLE;
  VALUES NEXT VALUE FOR seq1, NEXT VALUE FOR seq1, NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1, NEXT VALUE FOR seq1, NEXT VALUE FOR seq1;
  -- msg: CREATE SEQUENCE 1
  -- COL1: 10
  -- COL1: 15
  -- COL1: 20
  -- COL1: 10
  -- COL1: 15
  -- COL1: 20

``NEXT VALUE FOR`` is not part of the transaction, so a value is never handed
out twice, even if the transaction that used it is rolled back.

See Also
--------

- :doc:`alter-sequence`
- :doc:`drop-sequence`
