CREATE SEQUENCE
===============

.. contents::

Syntax
------

.. code-block:: text

  CREATE SEQUENCE [ IF NOT EXISTS ] <sequence_name> [ <option> ... ]

A sequence is used as an atomic counter. It is useful for generating unique and
sequential numbers.

A sequence can have a minimum and maximum value, and can be allowed to cycle
(wrap around) between them.

IF NOT EXISTS
-------------

With ``IF NOT EXISTS``, a sequence with the same name in the same schema isn't an
error. Nothing changes, and the result is ``CREATE SEQUENCE 0``. The existing
sequence keeps its options and its current value: the new options aren't compared
with it, or checked (other than their syntax). If the sequence doesn't exist,
it's the same as ``CREATE SEQUENCE``, so the result is ``CREATE SEQUENCE 1``. A
schema that doesn't exist is still an error.

``IF NOT EXISTS`` is a vsql extension, not standard SQL. It's flagged as
``V106-01`` (see :doc:`sql-flagging`).

Options
-------

Each ``<option>`` can be one of (in any order):

.. code-block:: text

   AS <data_type>
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

Without a ``MINVALUE`` (or with ``NO MINVALUE``), the minimum value is 1 for a
sequence with a positive ``INCREMENT BY``, and the smallest value of the data
type (-9223372036854775808 for a ``BIGINT``) for a negative one. Without a
``MAXVALUE``, the maximum value is the largest value of the data type
(9223372036854775807 for a ``BIGINT``) for a positive ``INCREMENT BY``, and -1
for a negative one. So by default a sequence starts at 1 (or -1), and a
``START WITH`` outside of these limits needs a ``MINVALUE`` or ``MAXVALUE``. A
``CYCLE`` starts again at the minimum value (or the maximum value for a negative
``INCREMENT BY``).

Data Type
---------

``AS <data_type>`` is the data type of the values of the sequence, which is
also the type of ``NEXT VALUE FOR``. It's ``BIGINT`` by default. It must be an
exact numeric type with a scale of 0: ``SMALLINT``, ``INTEGER``, ``BIGINT``,
``NUMERIC(p)`` or ``DECIMAL(p)``. Every other option must be a value of the
data type:

.. code-block:: sql

  CREATE SEQUENCE seq1 AS SMALLINT START WITH 32767;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  -- msg: CREATE SEQUENCE 1
  -- COL1: 32767
  -- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

  CREATE SEQUENCE seq2 AS SMALLINT MAXVALUE 40000;
  -- error 42601: syntax error: MAXVALUE (40000) is out of range for SMALLINT

The values are always within the range of a ``BIGINT``, so a ``NUMERIC`` or
``DECIMAL`` without a precision, or with a precision of more than 18, has the
same limits as a ``BIGINT``.

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
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  -- msg: CREATE SEQUENCE 1
  -- COL1: 1
  -- COL1: 2

A sequence will return an error if it tries to go beyond the allowed limits:

.. code-block:: sql

  CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  -- msg: CREATE SEQUENCE 1
  -- COL1: 10
  -- COL1: 15
  -- COL1: 20
  -- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

However, we can use ``CYCLE`` to allow the sequence to wrap around:

.. code-block:: sql

  CREATE SEQUENCE seq1 MINVALUE 10 INCREMENT BY 5 MAXVALUE 20 CYCLE;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2, 3) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2, 3) AS t;
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
