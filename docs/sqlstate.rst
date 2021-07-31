.. contents::

Handling Errors
===============

The error returned from ``query()`` will always one of the ``SQLState`` struct
types. Each type describes the error situation, but may also contain specific
fields appropriate for that error. See
`sqlstate.v <https://github.com/elliotchance/vsql/blob/main/vsql/sqlstate.v>`_
for struct definitions.

You can match on these to inspect the error further:

.. code-block:: v

    db.query('SELECT * FROM bar') or {
        match err {
            vsql.SQLState42P01 { // 42P01 = table not found
                println("I knew '$err.table_name' did not exist!")
            }
            else { panic(err) }
        }
    }

The ``err.code`` contains the integer representation of the SQLSTATE:

.. code-block:: v

    db.query('SELECT * FROM bar') or {
        sqlstate := vsql.sqlstate_from_int(err.code)
        println('$sqlstate: $err.msg')
        // 42P01: no such table: BAR

        if err.code == vsql.sqlstate_to_int('42P01') {
            println('table does not exist')
        }
    }

Or handling errors by class (first two letters):

.. code-block:: v

    db.query('SELECT * FROM bar') or {
        if err.code >= vsql.sqlstate_to_int('42000') &&
            err.code <= vsql.sqlstate_to_int('42ZZZ') {
            println('Class 42 — Syntax Error or Access Rule Violation')
        }
    }
    
SQLSTATE
========

``22012`` division by zero
--------------------------

**Examples**

.. code-block:: sql

  SELECT 2.5 / 0;
  -- error 22012: division by zero

``23502`` violates not-null constraint
--------------------------------------

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (f1 CHARACTER VARYING(10) NULL, f2 FLOAT NOT NULL);
  INSERT INTO t1 (f1, f2) VALUES ('a', NULL);
  -- msg: CREATE TABLE 1
  -- error 23502: violates non-null constraint: column F2

``42601`` syntax error
----------------------

**Examples**

.. code-block:: sql

  TABLE;
  -- error 42601: syntax error: at "TABLE"
  
  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (b) VALUES (123, 456);
  -- msg: CREATE TABLE 1
  -- error 42601: syntax error: INSERT has more values than columns
  
  CREATE TABLE ABS (a INT);
  -- error 42601: syntax error: table name cannot be reserved word: ABS

``42703`` column does not exist
-------------------------------

**Examples**

.. code-block:: sql

  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (c) VALUES (true);
  -- msg: CREATE TABLE 1
  -- error 42703: no such column: C

``42804`` data type mismatch
----------------------------

**Examples**

.. code-block:: sql

  SELECT 123 || 'bar';
  -- error 42804: data type mismatch cannot INTEGER || CHARACTER VARYING: expected another type but got INTEGER and CHARACTER VARYING
  
  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (b) VALUES (123);
  -- msg: CREATE TABLE 1
  -- error 42804: data type mismatch for column B: expected BOOLEAN but got INTEGER

``42883`` function does not exist
---------------------------------

**Examples**

.. code-block:: sql

  SELECT ABS();
  -- error 42883: function does not exist: ABS has 0 arguments but needs 1 argument
  
  SELECT ABS(1, 2);
  -- error 42883: function does not exist: ABS has 2 arguments but needs 1 argument

``42P01`` table does not exist
------------------------------

**Examples**

.. code-block:: sql

  DELETE FROM foo;
  -- error 42P01: no such table: FOO

``42P07`` table already exists
------------------------------

**Examples**

.. code-block:: sql

  CREATE TABLE foo (a FLOAT);
  CREATE TABLE foo (baz CHARACTER VARYING(10));
  -- msg: CREATE TABLE 1
  -- error 42P07: duplicate table: FOO
