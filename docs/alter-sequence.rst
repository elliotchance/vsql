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

   RESTART
   RESTART WITH <number>
   INCREMENT BY <number>
   MINVALUE <number>
   NO MINVALUE
   MAXVALUE <number>
   NO MAXVALUE
   CYCLE
   NO CYCLE

``RESTART`` (without using ``WITH <number>``) will go back to the ``START WITH``
value of the sequence.

Only ``RESTART`` changes the next value of the sequence. For example, changing
the ``INCREMENT BY`` will still return the same next value, and the new
increment is used after that.

A new ``MINVALUE <number>`` or ``MAXVALUE <number>`` must not exclude the next
value (or the ``RESTART`` value). Limits that aren't changed aren't checked, so
a sequence that has gone past its ``MAXVALUE`` can be continued with ``CYCLE``,
``NO MAXVALUE`` or a higher ``MAXVALUE``.

Examples
--------

.. code-block:: sql

   CREATE SEQUENCE seq1;
   VALUES NEXT VALUE FOR seq1, NEXT VALUE FOR seq1;
   ALTER SEQUENCE seq1 RESTART;
   VALUES NEXT VALUE FOR seq1, NEXT VALUE FOR seq1;
   -- msg: CREATE SEQUENCE 1
   -- COL1: 1
   -- COL1: 2
   -- msg: ALTER SEQUENCE 1
   -- COL1: 1
   -- COL1: 2

   CREATE SEQUENCE seq2;
   VALUES NEXT VALUE FOR seq2;
   ALTER SEQUENCE seq2 INCREMENT BY 5;
   VALUES NEXT VALUE FOR seq2, NEXT VALUE FOR seq2;
   -- msg: CREATE SEQUENCE 1
   -- COL1: 1
   -- msg: ALTER SEQUENCE 1
   -- COL1: 2
   -- COL1: 7

See Also
--------

- :doc:`create-sequence`
- :doc:`drop-sequence`
