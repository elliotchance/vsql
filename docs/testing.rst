.. contents::

vsql is tested exclusively with SQL test files. This page describes how to write
tests and optional functionality you might need.

Test Files
----------

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
-----

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
---------------

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
