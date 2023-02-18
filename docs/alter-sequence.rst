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
   VALUES NEXT VALUE FOR seq1, NEXT VALUE FOR seq1;
   ALTER SEQUENCE seq1 RESTART;
   VALUES NEXT VALUE FOR seq1, NEXT VALUE FOR seq1;
   -- msg: CREATE SEQUENCE 1
   -- COL1: 1 COL2: 2
   -- msg: ALTER SEQUENCE 1
   -- COL1: 1 COL2: 2

Caveats
-------

The properties of a sequence (such as the ``INCREMENT BY``, etc) are held in the
same record as the next value. Since the next value of a sequence needs to be
atomic (and separate from the transaction isolation) a ``ROLLBACK`` on a
transaction that contains an ``ALTER SEQUENCE`` will not undo any changes.

This was noted in :doc:`file-format` under *Notes for Future Improvements*.

See Also
--------

- :doc:`create-sequence`
- :doc:`drop-sequence`
