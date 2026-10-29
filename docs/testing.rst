Testing
=======

.. contents::

vsql is tested in a variety of ways, but most functional tests are SQL files
(see `SQL Tests`_).

This page explains what each test suite does and describes how to write tests
and optional functionality you might need.

Test Suites
-----------

``make test`` runs all of the test suites, which can also be run on their own:

- ``make sql-test``: the SQL tests, see `SQL Tests`_.
- ``make vorm-test``: the tests for the ORM driver.
- ``make unit-test``: the other V tests in ``vsql/``.
- ``make btree-test``: the B-Tree stress tests.
- ``make examples-test``: runs each example.
- ``make cli-test``: the CLI tests.
- ``make libvsql-test``: the tests for libvsql, see `libvsql`_.

CI runs ``make test``.

B-Tree
^^^^^^

The ``btree_test.v`` stress tests the B-Tree (on-disk and in-memory)
implementation by creating a variety of sized trees/files with randomly ordered
keys. This test suite more specifically verifies:

1. Trees of different sizes (1, 10, 100 and 1000) keys can be created by inserting random order keys (one at a time).
2. All keys are correctly iterated and in order.
3. Keys can be expired by a transaction, which is how rows are deleted and
   updated.

The B-Tree tests are run as part of ``make test``. However, you can run this
suite alone with:

.. code-block:: sh

   make btree-test

Note: by default, btree_test.v will do just one iteration, which is faster,
and ok while developing, but before making a PR or a release, you should use:

.. code-block:: sh

   TIMES=10 make btree-test

or even ideally:

.. code-block:: sh

   TIMES=100 make btree-test

CLI
^^^

CLI tests are a collection of shell scripts that are executed. The vast majority
of these are used to test the ``vsql`` executable itself, however, since they
are shell scripts they are not limited to this.

To run all CLI tests:

.. code-block:: sh

   make cli-test

Or, to run a single command test use the path without the ``.sh`` suffix:

.. code-block:: sh

   make cmd/tests/in

Each shell file must return a 0 (success) exit code. However, there are many
ways to verify that certain commands fail on purpose within the script itself.

The server tests connect with ``psql``. They are skipped if ``psql`` is not
installed, except on CI (when ``CI`` is set) where they fail instead.

There are some things to consider when writing CLI tests:

1. The file must end with ``.sh`` and contain a
`shebang <https://en.wikipedia.org/wiki/Shebang_(Unix)>`_ on the first line.

2. Remember to put ``set -e`` before any other commands. This will ensure that
if a command fails, that the script itself will halt and return the exit code.

3. A ``$VSQL`` will be provided for the true location of the ``vsql``
executable, you should not hardcode the binary location. This also makes it easy
to test the same scripts against different versions of vsql in the future.

Debugging
*********

Modify the ``set -e`` at the start of the file to be ``set -ex``. This will
print out each of the commands before they run.

Temporary Files
***************

Your test files should make temporary files as needed. This will prevent race
conditions and other errors with inconsistent state. Create a temporary file
with (replace the ``.vsql`` extension, if needed):

.. code-block:: sh

   VSQL_FILE="$(mktemp).vsql" || exit 1

Assertions
**********

You can use the following to verify that a file contains a string (it will not
match the whole line):

.. code-block:: sh

   grep -R 'CREATE TABLE "PUBLIC"."FOO"' $SQL_FILE

Conversely, ``grep -vR`` can be used to check a file does not contain a string.

To verify that a command failed (specifically did not succeed), you can use:

.. code-block:: sh

   (echo 'CREATE foo (bar INT);' | $VSQL in $VSQL_FILE) && exit 1 || true

Where ``echo 'CREATE foo (bar INT);' | $VSQL in $VSQL_FILE`` is the command to
be tested.

Examples
^^^^^^^^

The ``examples/`` directory contains simple programs that are both aimed at
demonstrating concepts and features but are also a test suite in their own
right.

Run all examples with:

.. code-block:: sh

   make examples-test

Or, you can run a single example with (notice there is no ``.v`` extension on
the path):

.. code-block:: sh

   make examples/virtual-tables

libvsql
^^^^^^^

The unit tests for libvsql, the SQL/CLI (Part 3) shared library for C programs
(see :doc:`sql-compliance`), are next to the V file that they test: the tests
for ``libvsql/std_3_6_30_get_data.v`` are in
``libvsql/std_3_6_30_get_data_test.c``. ``libvsql/test.h`` has the helpers and
fixtures that they share (implemented in ``libvsql/test.c``). The tests are
run as part of ``make test``, or on their own with:

.. code-block:: sh

   make libvsql-test

This builds the shared library (``bin/libvsql.so``, ``bin/libvsql.dylib`` on
macOS or ``bin/libvsql.dll`` on Windows), then runs
``scripts/check-libvsql-constants.vsh``, which checks that every ``#define
SQL_...`` in ``libvsql/libvsql.h`` has a ``const sql_...`` with the same value
in ``libvsql/*.v``, and the other way around. Then it compiles
``libvsql/test.c`` and the ``libvsql/*_test.c`` files against the library into
one program, and runs it.

The tests use `utest.h <https://github.com/sheredom/utest.h>`_
(``libvsql/utest.h``). Each test checks one case of a CLI routine, and is named
after the routine's Subclause of ISO/IEC 9075-3 (such as
``6_30_get_data_null_needs_indicator`` for 6.30, GetData). A fixture gives each
test its own handles, so the tests don't depend on each other:

- ``env``: an environment and a connection that isn't connected yet.
- ``db``: an environment, a connection to a new in-memory database and a
  statement.
- ``row``: the same as ``db``, with a row of different data types fetched.

Add a test with ``UTEST_F()`` (or ``UTEST()`` without a fixture), using the
``EXPECT_*()`` and ``ASSERT_*()`` macros of utest.h, and ``EXPECT_STATE()`` for
the SQLSTATE of the first diagnostic record of a handle:

.. code-block:: c

   UTEST_F(db, 6_21_fetch_no_statement) {
     EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
     EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
   }

A failed ``EXPECT_*()`` prints its line and keeps going, so every failure is
shown. ``ASSERT_*()`` stops the test, for a step that the rest of the test
depends on.

The tests, ``libvsql/example.c`` and ``libvsql/libvsql.h`` must be C99, so
they're compiled with ``-std=c99 -pedantic-errors -Wall -Wextra -Werror``.
``make examples-test`` runs the example in :doc:`language-c`, and also compiles
``libvsql/example.c`` as C++ (``-std=c++11``).

ORM
^^^

``vorm/vorm_test.v`` tests the ORM driver (see :doc:`language-v`) with V's
``sql db { ... }`` syntax. It's run as part of ``make test``, or on its own
with:

.. code-block:: sh

   make vorm-test

Like ``make sql-test``, it also prints how many lines of ``vorm/`` are covered
(see Coverage below). ``make vorm-test-uncovered`` prints each line that wasn't
covered.

The tests must cover every line of ``vorm/``, so ``make vorm-test`` fails if
they don't (unless ``$COVERAGE`` is ``0``).

SQL
^^^

The SQL test suite contains most of the functional tests. This is likely the
only test suite you will use when adding functionality or fixing bugs in vsql.
More description below.

SQL Tests
---------

Run all SQL tests with:

.. code-block:: sh

   make sql-test

All tests are in the ``tests/`` directory and each file contains individual
tests separated by an empty line:

.. code-block:: sql

   SELECT 1 FROM t1;
   SELECT *
   FROM foo;
   -- COL1: 1
   -- error 42P01: no such table: FOO
   
   SELECT 2 FROM t1;
   SELECT 3 FROM t1;
   -- COL1: 2
   -- COL1: 3

This describes two tests where each test is given an a brand new database (ie.
no tables are carried between tests).

Each test is run twice, first with an in-memory database and then with a
database file, and only passes if both pass. Both use 256 byte pages so that
even small tests split pages and store large values across several pages. Tests
that use the ``connection`` directive only run on disk, and catalogs from
``create_catalog`` are always in memory.

The statements are sent through the PostgreSQL server, which is embedded in the
test like an application would (see :doc:`server`), by a PostgreSQL client over
TCP. One server is shared by all of the tests. A PostgreSQL client can't use
some of the directives, so tests with ``types``, ``set``, ``fault``,
``disconnect``, ``create_catalog``, ``virtual_table``, ``out``, ``in`` or
``clock`` use the database directly instead. When the database is used
directly, every value is also read with the getters of a row (such as
``get_int``), which must give the same value.

A failure shows which one failed, such as ``(on disk through server)``.

All SQL statements are executed and each of the results collected and compared
to the comment immediately below.

A statement can span multiple lines but must be terminated by a ``;``.

Errors will be in the form of ``error SQLSTATE: message``.

Setup
^^^^^

An optional ``/* setup */`` can be placed at the top of the file to be run
before each test:

.. code-block:: sql

   /* setup */
   CREATE TABLE t1 (x FLOAT);
   INSERT INTO t1 (x) VALUES (0);
   
   SELECT 1 FROM t1;
   -- COL1: 1
   
   SELECT 2 FROM t1;
   -- COL1: 2

Dynamic Parameters
^^^^^^^^^^^^^^^^^^

The values of the dynamic parameters (each ``?``) are set with
``/* params value ... */``, in order. They're used by the statements that follow
it, until the next ``params`` or the end of the test. Each statement that has a
``?`` with a value also shows the statement with each value in place of its
``?``, so that the values can be checked:

.. code-block:: sql

   /* setup */
   CREATE TABLE t1 (x FLOAT, y VARCHAR(10));

   INSERT INTO t1 (x) VALUES (?);
   -- error 42P02: parameter does not exist: ?1

   /* params 2 'a' */
   INSERT INTO t1 (x, y) VALUES (?, ?);
   /* params 3 */
   UPDATE t1 SET x = x + ?;
   SELECT * FROM t1;
   -- sql: INSERT INTO t1 (x, y) VALUES (2.0e0, 'a')
   -- msg: INSERT 1
   -- sql: UPDATE t1 SET x = x + 3.0e0
   -- msg: UPDATE 1
   -- X: 5e0 Y: a

Each value is one of:

- A number, such as ``123``, which is a ``DOUBLE PRECISION``.
- A string, such as ``'it''s'``.
- ``NULL`` followed by its type, such as ``NULL BOOLEAN``.

``/* params */`` on its own removes all of the values.

Comments
^^^^^^^^

Ordinary comments are collected for the expected output. If you want to place an
ignored comment line you can prefix the line with ``-- #``:

.. code-block:: sql

   -- # This test adds some numbers.
   VALUES 1 + 2;
   -- COL1: 3

While the placement of comment lines does not matter, it is by convention that
comments pertaining to a specific test be joined (without a blank line) and
comments relating to the entire file or group of tests below use a empty line
separator:

.. code-block:: sql

   -- # The following tests are arithmetic.

   VALUES 1 + 2;
   -- COL1: 3

   VALUES 3 * 4;
   -- COL1: 12

Multiple Connections
^^^^^^^^^^^^^^^^^^^^

If a test needs to use more than one connection (such as for testing
transactions). You can connect or reuse an existing connection by name with the
``connection`` directive.

Tests that need to use more than one connection **must** use the ``connection``
directive as the first line in the test. This is to avoid an in-memory database
being used when the test begins.

.. code-block:: sql

   /* connection 1 */
   START TRANSACTION;
   /* connection 2 */
   START TRANSACTION;
   -- 1: msg: START TRANSACTION
   -- 2: msg: START TRANSACTION

Multiple connections only exist for the lifetime of this test. The first time a
connection name is seen it will spawn a new connection and subsequent references
will use the existing connection.

All SQL statements are still run synchronously and sequentially and their output
is prefixed with the connection name.

Connection names can be any single word including numbers for convenience. The
default connection name is named "main" but this should not be used or
referenced in tests to avoid unexpected behavior.

Faults
^^^^^^

A ``fault`` directive makes an operation fail the next time it's reached, so
that the code that handles the error can be tested:

.. code-block:: sql

   CREATE TABLE t (x INT);
   /* fault wal_write */
   INSERT INTO t (x) VALUES (1);
   SELECT * FROM t;
   -- msg: CREATE TABLE 1
   -- error 00000: wal_write failed (fault injected by test)

A number after the name makes it fail the nth time it's reached instead, such
as ``/* fault lock_shared 2 */``.

The faults are:

- ``open``: opening the database file.
- ``lock``: locking the database file to write to it.
- ``lock_shared``: locking the database file to read it.
- ``read_header``: reading the header of the database file.
- ``read_page``: reading a page from the database file.
- ``write_version``: the file needs a newer version of vsql to be changed.
- ``wal_write``: writing a statement to the write-ahead log, before it's
  committed.
- ``wal_torn_frame``: only half of the commit frame is written to the
  write-ahead log.
- ``wal_corrupt_frame``: the commit frame in the write-ahead log has the wrong
  checksum.
- ``wal_bad_magic``, ``wal_bad_header`` and ``wal_unknown_frame``: the
  write-ahead log is corrupt in other ways.
- ``checkpoint``: copying a committed statement from the write-ahead log into
  the database file (including when it's recovered).
- ``recover``: copying a statement that was left in the write-ahead log into
  the database file.
- ``session_shared``: changing the session lock back to shared, after
  recovering the transactions of a connection that stopped.
- ``isolation_start``: starting the isolation block of an operation on the
  file.
- ``isolation_end``: ending the isolation block of an operation on the file,
  which removes the rows that were deleted outside of a transaction.
- ``accept``: a server accepting a client. A test with a ``fault`` doesn't run
  through the server, so this is only used by the server tests in
  ``vsql/sql_test.v``.

Each fault is a ``fault_point()`` or ``fault_reached()`` call in the code, see
``vsql/fault.v``. A test with a fault only runs on disk.

A ``disconnect`` directive closes a connection without rolling back its
transaction, like a process that stopped:

.. code-block:: sql

   /* connection 1 */
   CREATE TABLE t (x INT);
   START TRANSACTION;
   INSERT INTO t (x) VALUES (1);
   /* disconnect 1 */
   /* connection 2 */
   SELECT * FROM t;

If a connection can't be opened (such as because of a fault), the error is in
the output, after the name of the connection, and the current connection
doesn't change.

Clock
^^^^^

Every test has the same time, 2022-07-04 09:05:03.120056 UTC, in a time zone
of +05:00. A ``clock`` directive changes the time zone of the current
connection, such as ``/* clock -05:00 */``, or ``/* clock real */`` uses the
real time and time zone (so the output can't include them):

.. code-block:: sql

   /* clock -05:00 */
   VALUES CURRENT_TIME;
   -- COL1: 04:05:03-0500

A test with ``clock`` doesn't run through the server.

Virtual Tables
^^^^^^^^^^^^^^

A ``virtual_table`` directive registers a virtual table (see
:doc:`virtual-tables`) on the current connection. It's a ``CREATE TABLE``,
followed by ``AS`` and a query for its rows:

.. code-block:: sql

   /* virtual_table CREATE TABLE fruits (id INT, name VARCHAR(10)) AS VALUES ROW(1, 'kiwi'), ROW(2, 'pear') */
   SELECT * FROM fruits;
   -- ID: 1 NAME: kiwi
   -- ID: 2 NAME: pear

The query is run when the virtual table is registered. If it can't be
registered, the error is in the output. The ``pg_database`` virtual table that
the server registers for PostgreSQL clients is also registered for each test.

Dump and Restore
^^^^^^^^^^^^^^^^

The ``out`` directive dumps the database like ``vsql out`` (see :doc:`cli`).
Each line of the dump is in the output, after ``out:``. The ``in`` directive
then replaces the database with a new one, which the last dump is loaded into
like ``vsql in``. Only the errors from loading the dump are in the output. The
statements after it use the restored database, so they can check that it's the
same:

.. code-block:: sql

   CREATE TABLE t (x INT);
   INSERT INTO t (x) VALUES (1);
   /* out */
   /* in */
   SELECT * FROM t;
   -- msg: CREATE TABLE 1
   -- msg: INSERT 1
   -- out: CREATE TABLE "PUBLIC"."T" (
   -- out:   "X" INTEGER
   -- out: );
   -- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (1);
   -- X: 1

``out`` and ``in`` can't be used with the ``connection`` directive.

Multiple Catalogs
^^^^^^^^^^^^^^^^^

If a test needs to use more than one catalog, you can use the ``create_catalog``
directive:

.. code-block:: sql

   /* create_catalog FOO */
   CREATE TABLE foo.public.bar (baz INTEGER);
   EXPLAIN SELECT * FROM foo.public.bar;
   -- msg: CREATE TABLE 1
   -- EXPLAIN: TABLE FOO.PUBLIC.BAR (BAZ INTEGER)
   -- EXPLAIN: EXPR (FOO.PUBLIC.BAR.BAZ INTEGER)

Unicode and Whitespace Characters
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Unicode characters can be placed in tests as regular characters:

.. code-block:: sql

   VALUES '✌️';
   -- That's a peach sign (or the logo for V) if the character cannot be read.

However, due to editors/IDEs sometimes handling whitespace in different ways
you can add a placeholder for a specific Unicode point using ``<U+####>``:

.. code-block:: sql

   VALUES<U+0009>'hi';
   -- U+0009 is a horizontal tab, equal to \t in most languages.

This will be replaced with the correct character before the test runs.

This is only a feature of SQL Tests, so will not work in any other context.

Exposing Types
^^^^^^^^^^^^^^

Use the ``/* types */`` directive to include each value type in the output. This
is useful to verify that literals or expressions are being represented as the
expected type.

.. code-block:: sql

   /* types */
   VALUES ROW(2 + 3 * 5, (2 + 3) * 5);
   -- COL1: 17 (SMALLINT) COL2: 25 (SMALLINT)

vsql Extensions
^^^^^^^^^^^^^^^

A test can only use standard SQL, so that the tests show how to write SQL that
works on other databases. Language that only vsql has (see
:doc:`sql-flagging`) must be listed by its Feature ID in an
``/* extensions */`` directive, and each Feature ID that's listed must be used
by at least one statement in the test:

.. code-block:: sql

   /* extensions V001-01 */
   EXPLAIN VALUES 1;
   -- EXPLAIN: VALUES (COL1 SMALLINT) = ROW(1)

A test fails if it uses an extension that isn't listed, or lists one that it
doesn't use. The ``/* setup */`` of a file can't use any extensions, so write
``DROP TABLE t RESTRICT`` rather than ``DROP TABLE t``.

Debugging Tests
---------------

Verbose Output
^^^^^^^^^^^^^^

By default tests will be silent, only outputting contextual information on
failure. A summary of the SQL tests is printed at the end, including the
location of each failed test:

.. code-block:: text

   SQL tests: 1549 passed, 1 failed, 1550 total
     FAILED tests/arithmetic.sql:3 (in memory through server, on disk through server)

The "Summary for running V tests" line printed by V does not include failed
tests, so always check the SQL tests summary (or the exit code).

However, in some cases (such as debugging crashes) you might want more
verbose output.

You can set the environment variable ``$VERBOSE`` to any value other than empty,
such as:

.. code-block:: sh

   VERBOSE=1 make sql-test

Running In Memory, On Disk or Without the Server
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each test runs in memory and on disk. To only run one of them, set ``$MEMORY``
or ``$FILE`` to ``0``. ``SERVER=0`` uses the database directly for every test
instead of through the server:

.. code-block:: sh

   # only run tests on disk
   MEMORY=0 make sql-test

   # only run tests in memory
   FILE=0 make sql-test

   # don't run tests through the server
   SERVER=0 make sql-test

Tests that use the ``connection`` or ``fault`` directive only run on disk, so
they are skipped with ``FILE=0``. These can be combined with ``$TEST`` below.

Running Specific Test Files
^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you need to debug a specific sql test file, or just want quicker iterations,
you can use the ``$TEST`` environment variable:

.. code-block:: sh

   # only run tests/transaction.sql
   TEST=transaction make sql-test

Running Specific Tests
^^^^^^^^^^^^^^^^^^^^^^

Even more specific than test files, you can run a single test by including the
line referenced in the output. This is the same as the last line of the expected
output.

For example the output a failed test output might be:

.. code-block:: text

       Left value:
         at tests/subquery.sql:32 (in memory):
   X: 123 Y: hello
       Right value:
         at tests/subquery.sql:32 (in memory):
   error 42601: syntax error: unknown column: Y

Running the specific test again can be done with:

.. code-block:: sh

   TEST=subquery:32 make sql-test

Coverage
^^^^^^^^

``make sql-test`` also prints how many lines in ``vsql/`` are run by the SQL
tests:

.. code-block:: text

   SQL test coverage: 87.22% (3379 of 3874 lines, run "make sql-test-uncovered" to see the rest)

When all of the tests are run, ``make sql-test`` fails unless every line is
covered. This is every line that V measures: V's coverage doesn't measure some
statements, such as a function call on its own line (including one ending in
``!``), an ``if`` condition or assigning to a map key. ``make sql-test-uncovered`` prints each line that wasn't covered by the
last ``make sql-test``:

.. code-block:: text

   vsql/table.v:73: mut names := []string{}
   vsql/table.v:78: return names

The same results are in ``coverage/sql.lcov``, which can be opened with any LCOV
viewer (such as the "Coverage Gutters" extension for VS Code). When only some of
the tests are run (such as with ``$TEST``, ``$MEMORY`` or ``$FILE``) the
coverage is only for those tests.

Code that can't be reached with SQL (such as the V API, the server, or a check
for something that can't happen) is tested by the V tests at the end of
``vsql/sql_test.v``, so it's also counted. A panic stops the process, so
``run_in_child()`` runs it in a child process and checks the message. The
child's coverage is still counted because it's written when the process exits.
The coverage build is compiled with ``-d coverage`` so that the code can tell
(see ``crash_point()``, which would otherwise exit without writing it).

``make test`` runs the SQL tests with ``make sql-test`` and the ORM tests with
``make vorm-test``, so CI also shows the coverage (in the log and the summary of
the run).

Coverage makes the tests a few seconds slower. Set ``$COVERAGE`` to ``0`` to
turn it off:

.. code-block:: sh

   COVERAGE=0 make sql-test
   COVERAGE=0 make vorm-test

``make vorm-test`` doesn't require 100% coverage of ``vorm/`` when it's turned
off.

Using Different V Versions
--------------------------

Sometimes there are V language changes which might break tests, or otherwise
cause issues on newer versions. Fortunately there is an ``oldv`` tool which can
be used to compile another version of ``v`` for testing. You can run tests
simply by supplying a different version of V:

.. code-block:: sh

   OLDV=a853af2 make sql-test

You can use any commit or tag for ``OLDV``. All tags can be
`found here <https://github.com/vlang/v/tags>`_.
