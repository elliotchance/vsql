Locking and Read-Only Databases
===============================

.. contents::

Many connections, in the same process or in different processes, can use the
same database file at the same time. This page explains how they wait for each
other, and what happens with a file that can only be read.

File Permissions
----------------

vsql always opens a database file for reading and writing, even if it's only
going to read it, and it creates lock files next to it (see :doc:`file-format`).
So the database file must be writable, and so must the directory that it's in.

If the directory can't be written to, connecting fails:

.. code-block:: text

   $ vsql cli db.vsql
   cli execution error: sql-client unable to establish sql-connection: unable to open db.vsql.session: Permission denied; ...

If only the database file can't be written to, every statement fails with a
``58030`` error, including a ``SELECT``:

.. code-block:: text

   vsql> SELECT * FROM t;
   Error 58030: unable to open db.vsql: Permission denied; code: 13

There's no option to open a file in a read-only mode. To query a file that you
don't have permission to change, copy it somewhere that you can write to
(with its ``.wal`` file, if there is one, see :doc:`file-format`).

Files That Need a Newer Version
-------------------------------

A file that uses a feature of a newer version of vsql may only be readable (see
:ref:`file-format:Compatibility`). Queries work as usual, but any
statement that changes the file fails with a ``25006`` error:

.. code-block:: text

   vsql> SELECT * FROM t;
   X
   -
   1
   1 row (1 ms)

   vsql> INSERT INTO t (x) VALUES (2);
   Error 25006: read-only sql transaction: database needs file format 65535 to be changed, but this version of vsql only supports up to 5

A transaction only locks or changes the file once one of its statements changes
the database, so a transaction that only reads (including ``START TRANSACTION``
and ``COMMIT``) works on such a file too (see :doc:`mvcc`).

Locks Between Processes
-----------------------

Each statement locks the database file while it runs: a shared lock to read it,
so that many statements can read at the same time, or an exclusive lock to
change it. The lock is released at the end of the statement, not the end of the
transaction. A statement waits for as long as it takes to get the lock, without
a timeout, but since another vsql statement only holds it while it runs, that's
usually not long. A program other than vsql that locks the file (with
``flock``) makes vsql wait until it's unlocked. On Windows, the lock is held on
a separate file, with the same name followed by ``.lock``, because a lock on
the database file itself would also stop it from being read.

Transactions are isolated from each other with more locks, on the lock files
next to the database file (see :doc:`transactions`):

- Only one ``SERIALIZABLE`` (the default) transaction that changes the database
  can be active at a time, and a statement outside of a transaction that changes
  the database counts as one. A ``READ ONLY`` transaction can't be active at the
  same time as one of those, but several ``READ ONLY`` transactions can be.

- A transaction that can't start yet waits for up to the ``lock_timeout`` of
  the connection, and then fails with a ``40001`` serialization failure. It's 5
  seconds by default, and can be changed with ``ConnectionOptions.lock_timeout``
  in V (see :ref:`language-v:Opening a Connection`). The CLI, ``vsql server`` and the C
  library (see :doc:`language-c`) always use the default.

- A ``READ COMMITTED`` or ``REPEATABLE READ`` transaction doesn't wait. If a
  ``SERIALIZABLE`` transaction is active when it commits its changes, it fails
  with a ``40001`` straight away, and is rolled back.

- A query outside of a transaction never waits for a transaction. It sees the
  changes that were committed before it started.

These locks work the same way whether the other connection is in the same
process or not. For example, while one ``vsql cli`` has a transaction that has
changed the database:

.. code-block:: text

   $ vsql cli db.vsql
   vsql> START TRANSACTION;
   START TRANSACTION (1 ms)

   vsql> INSERT INTO t (x) VALUES (2);
   INSERT 1 (0 ms)

Another ``vsql cli`` can still query the committed rows straight away, but a
statement that changes the database waits, and fails after 5 seconds if the
first transaction is still active:

.. code-block:: text

   $ vsql cli db.vsql
   vsql> SELECT * FROM t;
   X
   -
   1
   1 row (1 ms)

   vsql> INSERT INTO t (x) VALUES (3);
   Error 40001: serialization failure: timed out after 5.000s waiting for another connection to finish its transaction

If a process stops while it has a transaction, the operating system releases its
locks, so other connections don't wait for it. Its transaction is rolled back
later (see :ref:`mvcc:Crashed Transactions`).
