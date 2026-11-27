SET CONSTRAINTS
===============

.. contents::

Syntax
------

.. code-block:: text

  SET CONSTRAINTS { ALL | <constraint_name> , ... } { DEFERRED | IMMEDIATE }

``SET CONSTRAINTS`` changes whether ``DEFERRABLE`` constraints are deferred
(only checked at the ``COMMIT``) or immediate (checked at the end of each
statement) for the rest of the transaction. See
:ref:`create-table:Deferrable Constraints`.

``ALL`` is every ``DEFERRABLE`` constraint. A named constraint that isn't
``DEFERRABLE`` is an error ``42601``, and one that doesn't exist is an error
``42704``. The name can be qualified by the schema (and catalog).

A constraint that's made ``IMMEDIATE`` is checked straight away against every
row of its table, if a statement changed the table while it was deferred. If
the constraint isn't satisfied, it's an error (such as ``23505``) and the
constraint stays deferred.

Outside of a transaction, ``SET CONSTRAINTS`` is for the next transaction. Each
transaction ends with every constraint back to how it was defined (``INITIALLY
DEFERRED`` or not).

Examples
--------

.. code-block:: sql

  CREATE TABLE t (x INT CONSTRAINT u UNIQUE DEFERRABLE);
  INSERT INTO t (x) VALUES (1);

  START TRANSACTION;
  SET CONSTRAINTS u DEFERRED;
  INSERT INTO t (x) VALUES (1);
  SET CONSTRAINTS u IMMEDIATE;
  DELETE FROM t WHERE x = 1;
  COMMIT;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: START TRANSACTION
  -- msg: SET CONSTRAINTS
  -- msg: INSERT 1
  -- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
  -- msg: DELETE 2
  -- msg: COMMIT

See Also
--------

- :doc:`commit`
- :doc:`create-table`
- :doc:`start-transaction`
