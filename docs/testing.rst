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

.. code-block:: sql

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
