SQLSTATE
========

.. contents::

Handling Errors
---------------

The error returned from ``query()`` will always one of the ``SQLState`` struct
types. Each type describes the error situation, but may also contain specific
fields appropriate for that error. See
`sqlstate.v <https://github.com/elliotchance/vsql/blob/main/vsql/sqlstate.v>`_
for struct definitions.

You can match on these to inspect the error further:

.. code-block:: text

    db.query('SELECT * FROM bar') or {
        match err {
            vsql.SQLState42P01 { // 42P01 = table not found
                println("I knew '${err.entity_name}' did not exist!")
            }
            else { panic(err) }
        }
    }

The ``err.code()`` contains the integer representation of the SQLSTATE:

.. code-block:: text

    db.query('SELECT * FROM bar') or {
        sqlstate := vsql.sqlstate_from_int(err.code())
        println('$sqlstate: $err.msg()')
        // 42P01: no such table: BAR

        if err.code() == vsql.sqlstate_to_int('42P01') {
            println('table does not exist')
        }
    }

Or handling errors by class (first two letters):

.. code-block:: text

    db.query('SELECT * FROM bar') or {
        if err.code() >= vsql.sqlstate_to_int('42000') &&
            err.code() <= vsql.sqlstate_to_int('42ZZZ') {
            println('Class 42 — Syntax Error or Access Rule Violation')
        }
    }
    
SQLSTATE
--------

``0B000`` invalid transaction initiation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``0B000`` is caused when attempting to ``START TRANSACTION`` but there pool of
in-flight transactions is full.

``22001`` string data right truncation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This means a character value is trying to be converted to a type that is not
large enough to store it.

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x CHARACTER VARYING(8));
  INSERT INTO foo (x) VALUES ('hello');
  SELECT CAST(x AS VARCHAR(4)) FROM foo;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- error 22001: string data right truncation for CHARACTER VARYING(4)

``22003`` numeric value out of range
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x SMALLINT);
  INSERT INTO foo (x) VALUES (-32769);
  -- error 22003: numeric value out of range

``2200H`` sequence generator limit exceeded
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20 NO CYCLE;
  VALUES NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1;
  VALUES NEXT VALUE FOR seq1;
  -- msg: CREATE SEQUENCE 1
  -- COL1: 10
  -- COL1: 15
  -- COL1: 20
  -- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

``22012`` division by zero
^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  SELECT 2.5 / 0;
  -- error 22012: division by zero

``23502`` violates not-null constraint
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (f1 CHARACTER VARYING(10) NULL, f2 FLOAT NOT NULL);
  INSERT INTO t1 (f1, f2) VALUES ('a', NULL);
  -- msg: CREATE TABLE 1
  -- error 23502: violates non-null constraint: column F2

``25001`` invalid transaction state: active sql transaction
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``25001`` is caused by a transaction state transition that is not legal on an
already active transaction.

**Examples**

.. code-block:: sql

   START TRANSACTION;
   START TRANSACTION;
   -- error 25001: invalid transaction state: active sql transaction

``25P02`` in failed sql transaction
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``25P02`` will be returned for all commands within a transaction after a failure
of a previous SQL statement. You must ``COMMIT`` or ``ROLLBACK``, however,
``COMMIT`` will be treated as a ``ROLLBACK``.

**Examples**

.. code-block:: sql

   CREATE TABLE foo (b BOOLEAN);
   INSERT INTO foo (b) VALUES (123, 456);
   SELECT * FROM foo;
   -- msg: CREATE TABLE 1
   -- error 42601: syntax error: INSERT has more values than columns
   -- error 25P02: transaction is aborted, commands ignored until end of transaction block

``2BP01`` dependent objects still exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``2BP01`` occurs if trying to drop a schema with ``RESTRICT`` and there are
still objects that exist in the schema.

``2D000`` invalid transaction termination
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``2D000`` is caused by a transaction state transition that is not legal when not
in an active transaction.

**Examples**

.. code-block:: sql

   START TRANSACTION;
   COMMIT;
   COMMIT;
   -- error 2D000: invalid transaction termination

``3D000`` invalid catalog name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``3D000`` occurs if the catalog does not exist or is otherwise invalid.

``3F000`` invalid schema name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``3F000`` occurs if the schema does not exist or is otherwise invalid.

``40001`` serialization failure
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``40001`` occurs if concurrent transactions attempt to update the same row. If
allowed, this would lead to an inconsistency. It's possible that this also might
be a deadlock in some situations. However, the deadlock is always avoided
because the current transaction that receives this error will be rolled back.

A client that receives this error should retry the transaction.

``42601`` syntax error
^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  TABLE;
  -- error 42601: syntax error: at "TABLE"
  
  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (b) VALUES (123, 456);
  -- msg: CREATE TABLE 1
  -- error 42601: syntax error: INSERT has more values than columns
  
  CREATE TABLE ABS (x INT);
  -- error 42601: syntax error: table name cannot be reserved word: ABS

``42703`` column does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (c) VALUES (true);
  -- msg: CREATE TABLE 1
  -- error 42703: no such column: C

``42804`` data type mismatch
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  SELECT 123 || 'bar';
  -- error 42804: data type mismatch cannot INTEGER || CHARACTER VARYING: expected another type but got INTEGER and CHARACTER VARYING
  
  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (b) VALUES (123);
  -- msg: CREATE TABLE 1
  -- error 42804: data type mismatch for column B: expected BOOLEAN but got INTEGER

``42846`` cannot coerce
^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  VALUES CAST(123 AS BOOLEAN);
  -- error 42846: cannot coerce BIGINT to BOOLEAN

``42883`` function does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  SELECT ABS();
  -- error 42883: function does not exist: ABS has 0 arguments but needs 1 argument
  
  SELECT ABS(1, 2);
  -- error 42883: function does not exist: ABS has 2 arguments but needs 1 argument

``42P01`` table does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  DELETE FROM foo;
  -- error 42P01: no such table: FOO

``42P02`` parameter does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (x FLOAT);
  INSERT INTO t1 (x) VALUES (:foo);
  -- error 42P02: no such parameter: foo

``42P06`` schema already exists
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE foo;
  CREATE TABLE foo;
  -- msg: CREATE SCHEMA 1
  -- error 42P06: duplicate schema: FOO

``42P07`` table already exists
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x FLOAT);
  CREATE TABLE foo (baz CHARACTER VARYING(10));
  -- msg: CREATE TABLE 1
  -- error 42P07: duplicate table: FOO
