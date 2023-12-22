Testing
=======

.. contents::

vsql is tested in a variety of ways, but all functional tests are through the
SQL files.

This page explains what each test suite does and describes how to write tests
and optional functionality you might need.

Test Suites
-----------

B-Tree
^^^^^^

The ``btree_test.v`` stress tests the B-Tree (on-disk and in-memory)
implementation by creating a variety of sized trees/files with randomly ordered
keys for insertion and deletion. All keys are inserted then all keys are
removed. This test suite more specifically verifies:

1. Trees of different sizes (1, 10, 100 and 1000) keys can be created by inserting random order keys (one at a time).
2. All keys are correctly iterated and in order.
3. Removing all keys (one at a time) will correctly shrink the file as pages become empty.

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

   make cli-tests

Or, to run a single command test use the path without the ``.sh`` suffix:

.. code-block:: sh

   make cmd/tests/in-success

Each shell file must return a 0 (success) exit code. However, there are many
ways to verify that certain commands fail on purpose within the script itself.

There are some things to consider when writing CLI tests:

1. The file must end with ``.sh`` and contain a
`https://en.wikipedia.org/wiki/Shebang_(Unix) <shebang>`_ on the first line.

2. Remember to put ``set -e`` before any other commands. This will ensure that
if a command fails, that the script itself will halt and return the exit code.

3. A ``$VSQL`` will be provided for the true location of the ``vsql``
executable, you should not hardcode the binary location. This also makes it easy
to test the same scripts against different versions of vsql in the future.

Debugging
*********

Modify the ``set -e`` at the start of the file to be ``set -ex``. This will
print out each of the commmands before they run.

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

   grep -R "CREATE TABLE PUBLIC.FOO" $SQL_FILE

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

   make examples

Or, you can run a single example with (notice there is no ``.v`` extension on
the path):

.. code-block:: sh

   make examples/virtual-table

Connection
^^^^^^^^^^

The connection test suite is responsible for testing that various operations
from concurrent connections do not cause race conditions and other anomalies.

SQL
^^^

The SQL test suite contains all the functional tests. This is likely the only
test suite you will use when adding functionality or fixing bugs in vsql. More
description below.

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

All SQL statements are executed and each of the results collected and compared
to the comment immediately below.

A statement can span multiple lines but must me terminated by a `;`.

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

Host Parameters
^^^^^^^^^^^^^^^

Host parameters can be set with the ``/* set name value */`` and only exist for
the lifetime of a single test:

.. code-block:: sql

   /* setup */
   CREATE TABLE t1 (x FLOAT);
   
   INSERT INTO t1 (x) VALUES (:foo);
   -- error 42P02: parameter does not exist: foo
   
   /* set foo 2 */
   INSERT INTO t1 (x) VALUES (:foo);
   SELECT * FROM t1;
   -- msg: INSERT 1
   -- X: 2

There are slightly different forms depending on the type of the host parameter:

- ``/* set a 123 */`` for numeric values.
- ``/* set b 'foo' */`` for string values.
- ``/* set b NULL BOOLEAN */`` for ``NULL`` values (must specify a type).

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

All SQL statements are still run syncronously and sequentially and their output
is prefixed with the connection name.

Connection names can be any single word including numbers for convienience. The
default connection name is named "main" but this should not be used or
referenced in tests to avoid unexpected behavior.

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
   -- COL1: 17 (INTEGER) COL2: 25 (INTEGER)

Debugging Tests
---------------

Verbose Output
^^^^^^^^^^^^^^

By default tests will be silent, only outputting contextual information on
failure. However, in some cases (such as debugging crashes) you might want more
verbose output.

You can set the environment variable ``$VERBOSE`` to any value other than empty,
such as:

.. code-block:: sh

   VERBOSE=1 make sql-test

Running Specific Test Files
^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you need to debug a specific sql test file, or just want quicker iterations,
you can use the ``$TEST`` environment variable:

.. code-block:: sql

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
         at tests/subquery.sql:32:
   X: 123 Y: hello
       Right value:
         at tests/subquery.sql:32:
   error 42601: syntax error: unknown column: Y

Running the specific test again can be done with:

.. code-block:: sh

   TEST=subquery:32 make sql-test

Using Different V Versions
--------------------------

Sometimes there are V language changes which might break tests, or otherwise
cause issues on newer versions. Fortunatly there is a `oldv` tool which can be
used to compile older version of `v` for testing. You can run tests simply by
supplying a different version of V:

.. code-block:: sh

   OLDV=0.3.5 make sql-test

You can use any commit or tag for ``OLDV``. All tags can be
`found here <https://github.com/vlang/v/tags>`_.
