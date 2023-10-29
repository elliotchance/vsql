CREATE SEQUENCE
===============

.. contents::

Syntax
------

.. code-block:: text

  CREATE SEQUENCE <sequence_name> [ <option> ... ]

A sequence is used as an atomic counter. It is useful for generating unique and
sequential numbers.

The sequence can have an separately optional min and max values, as well as
being able to specify if numbers are allowed to cycle (wrap around) between
these boundaries.

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

A sequence will return an error if tries to go beyond the allowed limits:

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

However, we can use `CYCLE` to allow the sequence to wrap around:

.. code-block:: sql

  CREATE SEQUENCE seq1 MINVALUE 10 INCREMENT BY 5 MAXVALUE 20 CYCLE;
  VALUES ROW(NEXT VALUE FOR seq1, NEXT VALUE FOR seq1);
  VALUES ROW(NEXT VALUE FOR seq1, NEXT VALUE FOR seq1);
  VALUES ROW(NEXT VALUE FOR seq1, NEXT VALUE FOR seq1);
  -- msg: CREATE SEQUENCE 1
  -- COL1: 10 COL2: 15
  -- COL1: 20 COL2: 10
  -- COL1: 15 COL2: 20

See Also
--------

- :doc:`alter-sequence`
- :doc:`drop-sequence`
