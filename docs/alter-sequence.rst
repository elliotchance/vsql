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

Only ``RESTART`` changes the current value of the sequence, which is the last
value that ``NEXT VALUE FOR`` returned. For example, after changing the
``INCREMENT BY``, the next value is the last value plus the new increment. A
sequence that hasn't returned a value yet (or has been restarted) will still
return its ``START WITH`` (or ``RESTART``) value first.

``NO MINVALUE`` and ``NO MAXVALUE`` are the default limits described in
:doc:`create-sequence`, for the direction of the new ``INCREMENT BY``. Limits
that aren't given stay the same, even when ``INCREMENT BY`` changes the
direction of the sequence. For example, a sequence created without any options
that's changed to ``INCREMENT BY -1`` still has a minimum value of 1.

A new ``MINVALUE``, ``MAXVALUE``, ``NO MINVALUE`` or ``NO MAXVALUE`` must not
exclude the next value (or the ``RESTART`` value). Limits that aren't changed aren't checked, so
a sequence that has gone past its ``MAXVALUE`` can be continued with ``CYCLE``,
``NO MAXVALUE`` or a higher ``MAXVALUE``.

Examples
--------

.. code-block:: sql

   CREATE SEQUENCE seq1;
   SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
   ALTER SEQUENCE seq1 RESTART;
   SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
   -- msg: CREATE SEQUENCE 1
   -- COL1: 1
   -- COL1: 2
   -- msg: ALTER SEQUENCE 1
   -- COL1: 1
   -- COL1: 2

   CREATE SEQUENCE seq2;
   SELECT NEXT VALUE FOR seq2 FROM (VALUES 1) AS t;
   ALTER SEQUENCE seq2 INCREMENT BY 5;
   SELECT NEXT VALUE FOR seq2 FROM (VALUES 1, 2) AS t;
   -- msg: CREATE SEQUENCE 1
   -- COL1: 1
   -- msg: ALTER SEQUENCE 1
   -- COL1: 6
   -- COL1: 11

See Also
--------

- :doc:`create-sequence`
- :doc:`drop-sequence`
