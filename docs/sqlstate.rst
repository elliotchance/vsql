SQLSTATE
========

.. contents::

Handling Errors
---------------

The error returned from ``query()`` will always be one of the ``SQLState``
struct types. Each type describes the error situation, but may also contain
specific fields appropriate for that error. See
`std_2_24_1_sqlstate.v <https://github.com/elliotchance/vsql/blob/main/vsql/std_2_24_1_sqlstate.v>`_
for struct definitions.

This includes errors that aren't caused by the SQL itself, such as reading a
file (``58030``) or a file that isn't a vsql database (``XX001``). The only
exception is an error returned by your own code, such as a custom function (see
:doc:`custom-functions`) or a virtual table (see :doc:`virtual-tables`), which
is returned as it is.

You can match on these to inspect the error further:

.. code-block:: text

   db.query('SELECT * FROM bar') or {
   	match err {
   		// 42P01 = table not found
   		vsql.SQLState42P01 {
   			println("I knew '${err.entity_name}' did not exist!")
   		}
   		else {
   			panic(err)
   		}
   	}
   }

The ``err.code()`` contains the integer representation of the SQLSTATE:

.. code-block:: text

   db.query('SELECT * FROM bar') or {
   	sqlstate := vsql.sqlstate_from_int(err.code())
   	println('${sqlstate}: ${err.msg()}')
   	// 42P01: no such table: "test".PUBLIC.BAR

   	if err.code() == vsql.sqlstate_to_int('42P01') {
   		println('table does not exist')
   	}
   }

Or handling errors by class (first two letters):

.. code-block:: text

   db.query('SELECT * FROM bar') or {
   	if err.code() >= vsql.sqlstate_to_int('42000')
   		&& err.code() <= vsql.sqlstate_to_int('42ZZZ') {
   		println('Class 42 — Syntax Error or Access Rule Violation')
   	}
   }

See also
`examples/error-handling.v <https://github.com/elliotchance/vsql/blob/main/examples/error-handling.v>`_.

SQLSTATE
--------

``01003`` null value eliminated in set function
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``01003`` is a warning (the query still succeeds) when an aggregate function,
such as ``SUM(x)``, ignores one or more ``NULL`` values.

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x FLOAT);
  INSERT INTO foo (x) VALUES (NULL);
  INSERT INTO foo (x) VALUES (1.5);
  SELECT SUM(x) FROM foo;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: INSERT 1
  -- warning 01003: null value eliminated in set function
  -- COL1: 1.5e0

``01004`` string data, right truncation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``01004`` is a warning (the query still succeeds) when a ``CAST`` of a
character string to a shorter ``CHAR`` or ``VARCHAR`` removes characters that
aren't spaces. The value is truncated. Storing the same value in a column with
``INSERT`` or ``UPDATE`` is an error instead (``22001``).

**Examples**

.. code-block:: sql

  VALUES CAST('hello' AS VARCHAR(2));
  -- warning 01004: string data, right truncation
  -- COL1: he

``02000`` no data
^^^^^^^^^^^^^^^^^

``02000`` is a completion condition (the statement still succeeds, like a
warning) when an ``UPDATE`` or ``DELETE`` doesn't match any rows. The server
sends it as a ``NOTICE``.

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x INT);
  DELETE FROM foo;
  -- msg: CREATE TABLE 1
  -- warning 02000: no data
  -- msg: DELETE 0

``0A000`` feature not supported
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``0A000`` is returned when opening a database file (or its write-ahead log)
that needs a newer version of vsql, or was created by a version of vsql that is
too old. See *Compatibility* in :doc:`file-format`.

``0B000`` invalid transaction initiation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``0B000`` is caused when attempting to start a transaction but the pool of
in-flight transactions is full (see :doc:`limitations`).

``22001`` string data right truncation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This means a character value is trying to be converted to a type that is not
large enough to store it.

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x CHARACTER VARYING(4));
  INSERT INTO foo (x) VALUES ('hello');
  -- msg: CREATE TABLE 1
  -- error 22001: string data right truncation for CHARACTER VARYING(4)

A ``CAST`` to a shorter type is a ``01004`` warning instead.

``22003`` numeric value out of range
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x SMALLINT);
  INSERT INTO foo (x) VALUES (-32769);
  -- msg: CREATE TABLE 1
  -- error 22003: numeric value out of range

``22007`` invalid datetime format
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A character string cast to a date or time type must be a valid value for that
type.

**Examples**

.. code-block:: sql

  VALUES CAST('2022-02-30' AS DATE);
  -- error 22007: invalid datetime format

``2200B`` escape character conflict
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``ESCAPE`` of a ``SIMILAR TO`` can't be ``:`` when the pattern has a
character class such as ``[:ALPHA:]``.

**Examples**

.. code-block:: sql

  VALUES 'a' SIMILAR TO '[[:ALPHA:]]' ESCAPE ':';
  -- error 2200B: escape character conflict

``2200C`` invalid use of escape character
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When the ``ESCAPE`` of a ``SIMILAR TO`` is a character with a special meaning
(such as ``%``), it can only be used in the pattern to escape a character.

**Examples**

.. code-block:: sql

  VALUES 'abc' SIMILAR TO 'a%' ESCAPE '%';
  -- error 2200C: invalid use of escape character

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

``22011`` substring error
^^^^^^^^^^^^^^^^^^^^^^^^^

The length of a ``SUBSTRING`` must not be negative.

**Examples**

.. code-block:: sql

  VALUES SUBSTRING('hello' FROM 2 FOR -1);
  -- error 22011: substring error

``22012`` division by zero
^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  VALUES 2.5 / 0;
  -- error 22012: division by zero

``22018`` invalid character value for cast
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A character string cast to a number or a ``BOOLEAN`` must be a valid number or
boolean literal, once leading and trailing spaces are removed. A ``BOOLEAN``
cast to a character string that's too short for ``TRUE`` or ``FALSE`` is also
an error.

**Examples**

.. code-block:: sql

  VALUES CAST('abc' AS INT);
  -- error 22018: invalid character value for cast

``22019`` invalid escape character
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``ESCAPE`` of a ``LIKE`` or ``SIMILAR TO`` must be exactly one character.

**Examples**

.. code-block:: sql

  VALUES 'abc' LIKE 'a%' ESCAPE '!!';
  -- error 22019: invalid escape character

``2201B`` invalid regular expression
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The pattern of a ``SIMILAR TO`` is not a valid regular expression.

**Examples**

.. code-block:: sql

  VALUES 'abc' SIMILAR TO '(a';
  -- error 2201B: invalid regular expression

``2201E`` invalid argument for natural logarithm
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  VALUES LN(0e0);
  -- error 2201E: invalid argument for natural logarithm

``2201F`` invalid argument for power function
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  VALUES POWER(0e0, -1e0);
  -- error 2201F: invalid argument for power function

  VALUES SQRT(-1e0);
  -- error 2201F: invalid argument for power function

``2201W`` invalid row count in fetch first clause
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The row count of a ``FETCH FIRST`` must be one or more.

**Examples**

.. code-block:: sql

  VALUES 1, 2, 3 FETCH FIRST 0 ROWS ONLY;
  -- error 2201W: invalid row count in fetch first clause

``2201X`` invalid row count in result offset clause
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The row count of an ``OFFSET`` must not be negative.

**Examples**

.. code-block:: sql

  VALUES 1, 2, 3 OFFSET -1 ROWS;
  -- error 2201X: invalid row count in result offset clause

``22025`` invalid escape sequence
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In the pattern of a ``LIKE`` with an ``ESCAPE``, the escape character must be
followed by ``%``, ``_`` or the escape character.

**Examples**

.. code-block:: sql

  VALUES 'abc' LIKE 'a!bc' ESCAPE '!';
  -- error 22025: invalid escape sequence

``22027`` trim error
^^^^^^^^^^^^^^^^^^^^

The trim character must be exactly one character.

**Examples**

.. code-block:: sql

  VALUES TRIM('ab' FROM 'abcab');
  -- error 22027: trim error

``23502`` violates not-null constraint
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT NOT NULL);
  INSERT INTO t1 (f1, f2) VALUES ('a', NULL);
  -- msg: CREATE TABLE 1
  -- error 23502: violates non-null constraint: column F2

``23505`` violates unique constraint
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A row with the same ``PRIMARY KEY`` already exists.

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (id INT, PRIMARY KEY (id));
  INSERT INTO t1 (id) VALUES (1);
  INSERT INTO t1 (id) VALUES (1);
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T1

``23514`` violates check constraint
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A row doesn't satisfy a ``CHECK`` constraint of the table.

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (price INT CHECK (price > 0));
  INSERT INTO t1 (price) VALUES (0);
  -- msg: CREATE TABLE 1
  -- error 23514: violates check constraint: CHECK (PRICE > 0) on ":memory:".PUBLIC.T1

``25001`` invalid transaction state: active sql transaction
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``25001`` is caused by a transaction state transition that is not legal on an
already active transaction.

**Examples**

.. code-block:: sql

   START TRANSACTION;
   START TRANSACTION;
   -- msg: START TRANSACTION
   -- error 25001: invalid transaction state: active sql transaction

``25006`` read-only sql transaction
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``25006`` is returned for a statement that would change a database file that
was changed by a newer version of vsql, in a way that this version cannot
safely change it. The file can still be read. See *Compatibility* in
:doc:`file-format`.

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
   -- msg: START TRANSACTION
   -- msg: COMMIT
   -- error 2D000: invalid transaction termination

``3D000`` invalid catalog name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``3D000`` occurs if the catalog does not exist or is otherwise invalid.

**Examples**

.. code-block:: sql

  SET CATALOG 'nope';
  -- error 3D000: invalid catalog name: nope

``3F000`` invalid schema name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``3F000`` occurs if the schema does not exist or is otherwise invalid.

**Examples**

.. code-block:: sql

  SET SCHEMA 'NOPE';
  -- error 3F000: invalid schema name: NOPE

``40001`` serialization failure
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``40001`` occurs if concurrent transactions attempt to change (or delete) the
same row. If allowed, this would lead to an inconsistency. It's possible that
this also might be a deadlock in some situations. However, the deadlock is
always avoided because the current transaction that receives this error will be
rolled back.

A client that receives this error should retry the transaction. See
:doc:`transactions`.

``42501`` insufficient privilege
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``INFORMATION_SCHEMA`` (see :doc:`information-schema`) can't be changed.

**Examples**

.. code-block:: sql

  CREATE TABLE information_schema.foo (x INT);
  -- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

``42601`` syntax error
^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  TABLE;
  -- error 42601: syntax error: unexpected TABLE

  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (b) VALUES (123, 456);
  -- msg: CREATE TABLE 1
  -- error 42601: syntax error: INSERT has more values than columns

  CREATE TABLE ABS (x INT);
  -- error 42601: syntax error: unexpected ABS

``42602`` invalid name
^^^^^^^^^^^^^^^^^^^^^^

An identifier given to the API, such as the name in the prototype of a custom
function, can't be parsed.

``42702`` ambiguous column
^^^^^^^^^^^^^^^^^^^^^^^^^^

A column name without a table is in more than one table of the ``FROM`` clause.

**Examples**

.. code-block:: sql

  CREATE TABLE a (id INT);
  CREATE TABLE b (id INT);
  SELECT id FROM a JOIN b ON TRUE;
  -- msg: CREATE TABLE 1
  -- msg: CREATE TABLE 1
  -- error 42702: ambiguous column: ID

``42703`` column does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (c) VALUES (true);
  -- msg: CREATE TABLE 1
  -- error 42703: no such column: C

``42723`` function already exists
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A function with the same name and argument types has already been registered,
see :doc:`custom-functions`.

``42803`` grouping error
^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t (a INT, b INT);
  SELECT b, COUNT(*) FROM t GROUP BY a;
  -- msg: CREATE TABLE 1
  -- error 42803: column B must be in the GROUP BY clause or used in an aggregate function

``42804`` data type mismatch
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  VALUES 1, 'a';
  -- error 42804: data type mismatch in row 2, column 1 of VALUES: expected SMALLINT but got CHARACTER(1)

``42846`` cannot coerce
^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  VALUES CAST(123 AS BOOLEAN);
  -- error 42846: cannot coerce SMALLINT to BOOLEAN

  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (b) VALUES (123);
  -- msg: CREATE TABLE 1
  -- error 42846: cannot coerce SMALLINT to BOOLEAN

  VALUES CAST(DATE '2020-01-01' AS INT);
  -- error 42846: cannot coerce DATE to INTEGER

``42883`` function does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There is no function or operator with that name for the types of its arguments.

**Examples**

.. code-block:: sql

  VALUES ABS('hello');
  -- error 42883: function does not exist: ABS(CHARACTER(5))

  VALUES 123 || 'bar';
  -- error 42883: operator does not exist: SMALLINT || CHARACTER

``42P01`` table does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  DELETE FROM foo;
  -- error 42P01: no such table: ":memory:".PUBLIC.FOO

``42P02`` parameter does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (x FLOAT);
  INSERT INTO t1 (x) VALUES (:foo);
  -- msg: CREATE TABLE 1
  -- error 42P02: parameter does not exist: foo

``42P04`` catalog already exists
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``add_catalog()`` was called with the name of a catalog that already exists on
the connection.

``42P06`` schema already exists
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE SCHEMA foo;
  CREATE SCHEMA foo;
  -- msg: CREATE SCHEMA 1
  -- error 42P06: duplicate schema: FOO

``42P07`` table or sequence already exists
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x FLOAT);
  CREATE TABLE foo (baz CHARACTER VARYING(10));
  -- msg: CREATE TABLE 1
  -- error 42P07: duplicate table: ":memory:".PUBLIC.FOO

  CREATE SEQUENCE seq1;
  CREATE SEQUENCE seq1;
  -- msg: CREATE SEQUENCE 1
  -- error 42P07: duplicate sequence: ":memory:".PUBLIC.SEQ1

``42P10`` invalid column reference
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t (a INT, b INT);
  SELECT DISTINCT a FROM t ORDER BY b;
  -- msg: CREATE TABLE 1
  -- error 42P10: column B must be in the select list to be used in ORDER BY with SELECT DISTINCT

``54000`` program limit exceeded
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A table has more than 1600 columns:

.. code-block:: sql

  CREATE TABLE t (c1 INT, c2 INT, ..., c1601 INT);
  -- error 54000: table PUBLIC.T has 1601 columns, but the maximum is 1600

The name of a schema or sequence is part of the key of an object in the file,
so it must fit in a page. This can only happen with a small page size.

``ConnectionOptions.page_size`` must be more than 16 and at most 65535 bytes
when a database is created.

``58030`` io error
^^^^^^^^^^^^^^^^^^

Opening, locking, reading or writing a file (including the write-ahead log)
failed. The message has the reason from the operating system. The statement has
no effect.

``XX000`` internal error
^^^^^^^^^^^^^^^^^^^^^^^^

Something that should never happen, which is a bug in vsql. Please
`report it <https://github.com/elliotchance/vsql/issues>`_.

``XX001`` data corrupted
^^^^^^^^^^^^^^^^^^^^^^^^

The file is not a vsql database, or something in it isn't valid.
