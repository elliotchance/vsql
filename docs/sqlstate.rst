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

SQLSTATE Classes
----------------

A SQLSTATE is five characters. The first two are the class, which is the kind
of condition, and the last three are the subclass. A subclass of ``000`` is the
class without any more detail, such as ``22000`` for a data exception. Classes
``00`` (successful completion), ``01`` (warning) and ``02`` (no data) are
completion conditions, where the statement still succeeds. Every other class is
an exception, where the statement fails.

The SQLSTATEs that vsql returns are listed below under their class.

Class ``01``: Warning
---------------------

The statement succeeded, but something happened that you may want to know
about. A warning doesn't stop the statement or roll back the transaction.

``01001`` cursor operation conflict
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``01001`` is a warning (the statement still succeeds) when a positioned
``DELETE`` or ``UPDATE`` changes a row that another statement has changed since
the cursor was opened, or the other way around. See :doc:`cursors`.

**Examples**

.. code-block:: sql

  CREATE TABLE foo (x INT, y INT);
  INSERT INTO foo (x, y) VALUES (1, 10);
  START TRANSACTION;
  DECLARE c CURSOR FOR SELECT * FROM foo;
  OPEN c;
  FETCH c;
  UPDATE foo SET y = 5 WHERE x = 1;
  UPDATE foo SET y = 3 WHERE CURRENT OF c;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: START TRANSACTION
  -- msg: DECLARE CURSOR
  -- msg: OPEN
  -- X: 1 Y: 10
  -- msg: UPDATE 1
  -- warning 01001: cursor operation conflict: C
  -- msg: UPDATE 1

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

``01012`` invalid number of conditions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``01012`` is a warning when the ``DIAGNOSTICS SIZE`` of :doc:`set-transaction`
is more than 100, which is used instead.

Class ``02``: No Data
---------------------

The statement succeeded but there were no rows for it to act on. Like a
warning, this is a completion condition rather than an error.

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

Class ``08``: Connection Exception
----------------------------------

A connection couldn't be opened, used or closed.

``08001`` sql-client unable to establish sql-connection
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``08001`` is returned when :doc:`connect` (or the first statement of
:doc:`cli`) can't open the database file.

``08002`` connection name in use
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``08002`` is returned when :doc:`connect` uses the name of a connection that
already exists.

``08003`` connection does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``08003`` is returned by :doc:`set-connection` or :doc:`disconnect` for a
connection that doesn't exist, or for a statement when there is no current
connection after :doc:`disconnect`.

Class ``0A``: Feature Not Supported
-----------------------------------

The statement is valid but uses something that vsql doesn't support, or a file
that this version of vsql can't open.

``0A000`` feature not supported
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``0A000`` is returned when opening a database file (or its write-ahead log)
that needs a newer version of vsql, or was created by a version of vsql that is
too old. See *Compatibility* in :doc:`file-format`.

It's also returned for an aggregate function of only the columns of an outer
query in a correlated subquery, such as ``(SELECT MAX(t1.x) FROM t2)``, which
isn't supported yet.

``0A001`` feature not supported: multiple server transactions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``0A001`` is returned by :doc:`connect` or :doc:`set-connection` when the
current connection has an active transaction, since a transaction can't be
across more than one database. It's also always returned by
``SET LOCAL TRANSACTION`` (see :doc:`set-transaction`).

Class ``0B``: Invalid Transaction Initiation
--------------------------------------------

A transaction couldn't be started.

``0B000`` invalid transaction initiation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``0B000`` is caused when attempting to start a transaction but the pool of
in-flight transactions is full (see :doc:`limitations`).

Class ``21``: Cardinality Violation
-----------------------------------

A query returned a different number of rows than was expected where it was
used.

``21000`` cardinality violation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A subquery used as a value (a scalar subquery) returned more than one row. A
scalar subquery that returns no rows is ``NULL``.

**Examples**

.. code-block:: sql

  VALUES (SELECT x FROM (VALUES 1, 2) AS t (x));
  -- error 21000: cardinality violation: more than one row returned by a subquery used as an expression

Class ``22``: Data Exception
----------------------------

A value was invalid for the operation it was used in, such as being out of
range for a type, the wrong format for a ``CAST`` or an invalid argument for a
function. These are found while the statement runs, so they depend on the
data.

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

``LISTAGG`` also returns this error when its result would be longer than
10485760 characters, unless it has ``ON OVERFLOW TRUNCATE``.

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

The pattern of a ``SUBSTRING`` with ``SIMILAR`` must have exactly two of the
escape character followed by a double quote.

**Examples**

.. code-block:: sql

  VALUES 'abc' SIMILAR TO 'a%' ESCAPE '%';
  -- error 2200C: invalid use of escape character

  VALUES SUBSTRING('abc' SIMILAR '%b%' ESCAPE '#');
  -- error 2200C: invalid use of escape character

``2200H`` sequence generator limit exceeded
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20 NO CYCLE;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
  SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
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

The ``ESCAPE`` of a ``LIKE``, ``SIMILAR TO`` or ``SUBSTRING`` with ``SIMILAR``
must be exactly one character.

**Examples**

.. code-block:: sql

  VALUES 'abc' LIKE 'a%' ESCAPE '!!';
  -- error 22019: invalid escape character

``2201B`` invalid regular expression
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The pattern of a ``SIMILAR TO`` (or a part of the pattern of a ``SUBSTRING``
with ``SIMILAR``) is not a valid regular expression.

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

``2201G`` invalid argument for width bucket function
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The count of a ``WIDTH_BUCKET`` must be positive, and its bounds can't be equal.

**Examples**

.. code-block:: sql

  VALUES WIDTH_BUCKET(5, 0, 10, 0);
  -- error 2201G: invalid argument for width bucket function

  VALUES WIDTH_BUCKET(5, 1, 1, 3);
  -- error 2201G: invalid argument for width bucket function

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

``22029`` noncharacter in UCS string
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A character string can't contain a Unicode noncharacter (U+FDD0 to U+FDEF, and
the last two code points of each plane).

**Examples**

.. code-block:: sql

  VALUES U&'\FFFF';
  -- error 22029: noncharacter in UCS string

Class ``23``: Integrity Constraint Violation
--------------------------------------------

A change to a table would break one of its constraints. The statement has no
effect.

``23502`` violates not-null constraint
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT NOT NULL);
  INSERT INTO t1 (f1, f2) VALUES ('a', NULL);
  -- msg: CREATE TABLE 1
  -- error 23502: violates non-null constraint: column F2

``23503`` violates foreign key constraint
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A row doesn't reference a row of the table that a ``FOREIGN KEY`` references,
or a row that's referenced was deleted or its referenced columns were changed.

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (id INT PRIMARY KEY);
  CREATE TABLE t2 (t1_id INT REFERENCES t1);
  INSERT INTO t2 (t1_id) VALUES (1);
  -- msg: CREATE TABLE 1
  -- msg: CREATE TABLE 1
  -- error 23503: violates foreign key constraint: FOREIGN KEY (T1_ID) REFERENCES ":memory:".PUBLIC.T1 (ID) on ":memory:".PUBLIC.T2

``23505`` violates unique constraint
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A row with the same ``PRIMARY KEY``, or the same values for the columns of a
``UNIQUE`` constraint or a ``UNIQUE`` index (see :doc:`create-index`), already
exists.

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

Class ``24``: Invalid Cursor State
----------------------------------

A cursor isn't in the right state for the statement that uses it.

``24000`` invalid cursor state
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``24000`` occurs if a cursor isn't in the right state for the statement, such
as a ``FETCH`` of a cursor that isn't open, or a ``DELETE ... WHERE CURRENT OF``
a cursor that isn't positioned on a row (see :doc:`cursors`).

**Examples**

.. code-block:: sql

  DECLARE c CURSOR FOR SELECT * FROM products;
  FETCH c;
  -- error 24000: invalid cursor state: cursor C is not open

Class ``25``: Invalid Transaction State
---------------------------------------

The statement can't be run in the current state of the transaction.

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

``25006`` is returned for a statement that would change the database in a
``READ ONLY`` transaction (see :doc:`set-transaction`).

It's also returned for a statement that would change a database file that was
changed by a newer version of vsql, in a way that this version cannot safely
change it. The file can still be read. See *Compatibility* in
:doc:`file-format`.

**Examples**

.. code-block:: sql

   CREATE TABLE t (x INT);
   START TRANSACTION READ ONLY;
   INSERT INTO t (x) VALUES (1);
   -- msg: CREATE TABLE 1
   -- msg: START TRANSACTION
   -- error 25006: read-only sql transaction: cannot execute INSERT

``25008`` held cursor requires same isolation level
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``25008`` is returned when :doc:`set-transaction` or :doc:`start-transaction`
sets a different isolation level while a holdable cursor is still open from the
previous transaction.

Class ``27``: Triggered Data Change Violation
---------------------------------------------

The changes made by referential actions would conflict with each other.

``27000`` triggered data change violation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``27000`` is returned when the referential actions (such as ``ON DELETE SET
NULL``) of a statement would change a column of a row to two different values,
or both change and delete a row. See :doc:`create-table`.

Class ``28``: Invalid Authorization Specification
-------------------------------------------------

The user given for a connection isn't valid.

``28000`` invalid authorization specification
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``28000`` is returned when the ``USER`` of :doc:`connect` isn't an
identifier.

Class ``2B``: Dependent Privilege Descriptors Still Exist
---------------------------------------------------------

An object can't be dropped because other objects still depend on it. vsql
uses the PostgreSQL code ``2BP01`` for this.

``2BP01`` dependent objects still exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``2BP01`` occurs if trying to drop a schema with ``RESTRICT`` and there are
still objects that exist in the schema, a table or constraint that's
referenced by a ``FOREIGN KEY``, or a column that's in an index.

Class ``2C``: Invalid Character Set Name
----------------------------------------

The name of a character set isn't valid.

``2C000`` invalid character set name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``2C000`` is returned by :doc:`set-names` for anything other than ``UTF8``.

Class ``2E``: Invalid Connection Name
-------------------------------------

The name of a connection isn't valid.

``2E000`` invalid connection name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``2E000`` is returned when the name of a connection in :doc:`connect` isn't
an identifier.

Class ``34``: Invalid Cursor Name
---------------------------------

A cursor name doesn't refer to a cursor that can be used for the statement.

``34000`` invalid cursor name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``34000`` occurs if a cursor hasn't been declared with the name, or a positioned
``DELETE`` or ``UPDATE`` uses a cursor that isn't updatable (see
:doc:`cursors`).

**Examples**

.. code-block:: sql

  OPEN c;
  -- error 34000: invalid cursor name: cursor C does not exist

Class ``35``: Invalid Condition Number
--------------------------------------

The number of diagnostic conditions isn't valid.

``35000`` invalid condition number
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``35000`` is returned when the ``DIAGNOSTICS SIZE`` of :doc:`set-transaction`
or :doc:`start-transaction` is less than 1.

Class ``3B``: Savepoint Exception
---------------------------------

A savepoint couldn't be used.

``3B001`` savepoint exception: invalid specification
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``3B001`` is returned when :doc:`savepoint` uses the name of a savepoint that
doesn't exist in the current transaction.

Class ``3D``: Invalid Catalog Name
----------------------------------

A catalog name doesn't refer to a catalog of the connection.

``3D000`` invalid catalog name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``3D000`` occurs if the catalog does not exist or is otherwise invalid.

**Examples**

.. code-block:: sql

  SET CATALOG 'nope';
  -- error 3D000: invalid catalog name: nope

Class ``3F``: Invalid Schema Name
---------------------------------

A schema name doesn't refer to a schema that exists.

``3F000`` invalid schema name
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``3F000`` occurs if the schema does not exist or is otherwise invalid.

**Examples**

.. code-block:: sql

  SET SCHEMA 'NOPE';
  -- error 3F000: invalid schema name: NOPE

Class ``40``: Transaction Rollback
----------------------------------

The whole transaction was rolled back, so nothing that it changed was kept.
The only exception is when the rollback also fails (see ``40V01``).

``40001`` serialization failure
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``40001`` occurs if concurrent transactions attempt to change (or delete) the
same row. If allowed, this would lead to an inconsistency. It's possible that
this also might be a deadlock in some situations. However, the deadlock is
always avoided because the current transaction that receives this error will be
rolled back.

It also occurs when a ``SERIALIZABLE`` transaction (including a statement on
its own) waited too long for another connection's transaction to finish, when a
``READ COMMITTED`` or ``REPEATABLE READ`` transaction commits changes while
another connection has a ``SERIALIZABLE`` transaction, or when a
``REPEATABLE READ`` transaction changes something that another transaction has
changed since it started. See *Isolation Levels* in :doc:`transactions`.

A client that receives this error should retry the transaction. See
:doc:`transactions`.

``40002`` integrity constraint violation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A deferred constraint (see "Deferrable Constraints" in :doc:`create-table`)
isn't satisfied at the ``COMMIT``. The whole transaction is rolled back.

**Examples**

.. code-block:: sql

  CREATE TABLE t (x INT UNIQUE INITIALLY DEFERRED);
  INSERT INTO t (x) VALUES (1);
  START TRANSACTION;
  INSERT INTO t (x) VALUES (1);
  COMMIT;
  -- error 40002: integrity constraint violation: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T

``40V01`` transaction rollback
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

An error other than a constraint that isn't satisfied (such as an I/O error)
prevented a ``COMMIT``. The whole transaction is rolled back, and the message
has the original error.

If it couldn't be rolled back either, the error is the one that prevented that
instead, the message says that the transaction is still active, and the
``COMMIT`` can be tried again.

Class ``42``: Syntax Error or Access Rule Violation
---------------------------------------------------

The statement isn't valid SQL, refers to something that doesn't exist, or
isn't allowed. Most of these are found before the statement runs. Codes that end in ``P`` and a number are the same as PostgreSQL, since
the standard has no code for them.

``42501`` insufficient privilege
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``INFORMATION_SCHEMA`` (see :doc:`information-schema`) can't be changed.

**Examples**

.. code-block:: sql

  CREATE TABLE information_schema.foo (x INT);
  -- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

``42601`` syntax error
^^^^^^^^^^^^^^^^^^^^^^

When a statement can't be parsed, the error says which token wasn't expected,
where it is (the line and column, which start at 1) and the text around it on
that line. It also lists what was expected, if there are only a few. For some
common mistakes there is a hint after it, such as a reserved word that's used as
a name (see :doc:`keywords`), a missing or extra comma, or the syntax of another
database (such as ``AUTO_INCREMENT``, ``SERIAL`` or ``SELECT TOP``).

**Examples**

.. code-block:: sql

  TABLE;
  -- error 42601: syntax error: unexpected $end at line 1, column 6 near "TABLE"

  CREATE TABLE t (a INT NOT NULL DEFAULT 3);
  -- error 42601: syntax error: unexpected DEFAULT at line 1, column 32 near "INT NOT NULL DEFAULT 3", expecting ")" or ","; hint: the DEFAULT of a column must be before its constraints, such as x INTEGER DEFAULT 0 NOT NULL (see https://vsql.readthedocs.io/en/latest/create-table.html#defaults)

  CREATE TABLE foo (b BOOLEAN);
  INSERT INTO foo (b) VALUES (123, 456);
  -- msg: CREATE TABLE 1
  -- error 42601: syntax error: INSERT has more values than columns

  CREATE TABLE ABS (x INT);
  -- error 42601: syntax error: unexpected ABS at line 1, column 14 near "CREATE TABLE ABS ("; hint: ABS is a reserved word, so it must be quoted to be used as a name, such as "ABS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

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

``42704`` object does not exist
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t (a INT);
  ALTER TABLE t DROP CONSTRAINT foo;
  -- msg: CREATE TABLE 1
  -- error 42704: no such constraint: FOO on ":memory:".PUBLIC.T

``42710`` object already exists
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Examples**

.. code-block:: sql

  CREATE TABLE t (a INT CONSTRAINT foo CHECK (a > 0));
  CREATE TABLE u (a INT CONSTRAINT foo UNIQUE);
  -- msg: CREATE TABLE 1
  -- error 42710: duplicate constraint: FOO

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

``42830`` invalid foreign key
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The columns that a ``FOREIGN KEY`` references aren't the ``PRIMARY KEY`` or a
``UNIQUE`` constraint of the referenced table, or there's a different number of
them.

**Examples**

.. code-block:: sql

  CREATE TABLE t1 (id INT);
  CREATE TABLE t2 (t1_id INT REFERENCES t1);
  -- msg: CREATE TABLE 1
  -- error 42830: invalid foreign key: ":memory:".PUBLIC.T1 has no PRIMARY KEY

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

``428C9`` generated always
^^^^^^^^^^^^^^^^^^^^^^^^^^

A generated column, or an identity column that's ``GENERATED ALWAYS``, can only
be assigned ``DEFAULT``, see :doc:`create-table`.

**Examples**

.. code-block:: sql

  CREATE TABLE foo (id INTEGER GENERATED ALWAYS AS IDENTITY, x INTEGER);
  INSERT INTO foo (id, x) VALUES (5, 1);
  -- msg: CREATE TABLE 1
  -- error 428C9: cannot assign a value other than DEFAULT to column ID, which is GENERATED ALWAYS

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
  INSERT INTO t1 (x) VALUES (?);
  -- msg: CREATE TABLE 1
  -- error 42P02: parameter does not exist: ?1

``42P03`` duplicate cursor
^^^^^^^^^^^^^^^^^^^^^^^^^^

A cursor has already been declared with the name (see :doc:`cursors`).

**Examples**

.. code-block:: sql

  DECLARE c CURSOR FOR SELECT * FROM products;
  DECLARE c CURSOR FOR SELECT * FROM products;
  -- error 42P03: duplicate cursor: C

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

Class ``54``: Program Limit Exceeded
------------------------------------

The statement went beyond a limit of vsql (see :doc:`limitations`). This
class, and the classes after it, aren't in the SQL standard. They're the same as
PostgreSQL.

``54000`` program limit exceeded
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A table has more than 1600 columns:

.. code-block:: sql

  CREATE TABLE t (c1 INT, c2 INT, ..., c1601 INT);
  -- error 54000: table PUBLIC.T has 1601 columns, but the maximum is 1600

The name of a schema or sequence is part of the key of an object in the file,
so it must fit in a page. This can only happen with a small page size. So are
the values of the columns of an index (see :doc:`create-index`), which must fit
in half a page.

``ConnectionOptions.page_size`` must be more than 16 and at most 65535 bytes
when a database is created.

Class ``55``: Object Not In Prerequisite State
----------------------------------------------

An object wasn't in a state that allowed the statement to run.

``55P03`` lock not available
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``CREATE INDEX`` waited for ``create_index_timeout`` (60 seconds by default)
for other transactions with changes to the table to finish (see
:doc:`create-index`). Nothing was changed, so it can be tried again.

Class ``57``: Operator Intervention
-----------------------------------

``57014`` query canceled
^^^^^^^^^^^^^^^^^^^^^^^^

The statement was stopped by ``Connection.cancel()`` from another thread. Like
any other exception, the statement has no effect, and the transaction it's in
continues. libvsql raises ``HY008`` (operation canceled) instead, see
``SQLCancel``.

Class ``58``: System Error
--------------------------

An error outside of vsql, such as from the operating system.

``58030`` io error
^^^^^^^^^^^^^^^^^^

Opening, locking, reading or writing a file (including the write-ahead log)
failed. The message has the reason from the operating system. The statement has
no effect.

Class ``XX``: Internal Error
----------------------------

vsql found a problem with itself or with the database file.

``XX000`` internal error
^^^^^^^^^^^^^^^^^^^^^^^^

Something that should never happen, which is a bug in vsql. Please
`report it <https://github.com/elliotchance/vsql/issues>`_.

``XX001`` data corrupted
^^^^^^^^^^^^^^^^^^^^^^^^

The file is not a vsql database, or something in it isn't valid.
