ALTER SEQUENCE
==============

.. contents::

Syntax
------

.. code-block:: text

  ALTER SEQUENCE <sequence_name> { <option> ... }

Modify properties of a sequence.

Options
-------

Each ``<option>`` can be one of (in any order):

.. code-block:: text

   RESET
   RESET WITH <number>
   INCREMENT BY <number>
   MINVALUE <number>
   NO MINVALUE
   MAXVALUE <number>
   NO MAXVALUE

``RESET`` (without using ``WITH <number>``) will choose the smallest starting
number that is allowed by the other constraints.

Examples
--------

.. code-block:: sql

   CREATE SEQUENCE seq1;
   VALUES ROW(NEXT VALUE FOR seq1, NEXT VALUE FOR seq1);
   ALTER SEQUENCE seq1 RESTART;
   VALUES ROW(NEXT VALUE FOR seq1, NEXT VALUE FOR seq1);
   -- msg: CREATE SEQUENCE 1
   -- COL1: 1 COL2: 2
   -- msg: ALTER SEQUENCE 1
   -- COL1: 1 COL2: 2

See Also
--------

- :doc:`create-sequence`
- :doc:`drop-sequence`
