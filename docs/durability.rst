Durability
==========

.. contents::

A database file is changed one statement at a time. Each statement that changes
the database is atomic: if the process stops (it crashes or is killed) or the
power fails part way through, the file has either all or none of the changes
made by the statement. Once a statement has finished, it's durable, so it's
still there after the process stops (but see `Power Failures on macOS`_).

A transaction (see :doc:`transactions`) may contain many statements. It's
atomic too: a transaction that hadn't been committed when its process stopped is
rolled back, so none of its changes are ever seen by another connection. A
``COMMIT`` is a statement like any other, so once it has finished the whole
transaction is durable.

An in-memory database (see :doc:`in-memory-database`) is never written to the
disk, so nothing in it survives the process.

Files
-----

A database file (such as ``mydb.vsql``) has other files next to it while it's
open, with the same name followed by another extension:

- ``.wal`` is the write-ahead log. It **must not be deleted** while it exists,
  because it may contain the only copy of a statement that was committed (see
  `Crash Recovery`_).

- ``.session``, ``.isolation`` and ``.deferred`` (and the ``.queue`` files
  that go with them) are always empty, and are only used for locking (see
  :doc:`locking`). They can be deleted whenever there are no open connections
  to the database.

The last connection to close puts everything from the log into the database
file and deletes the log and the lock files (except on Windows, where the lock
files are kept), so that only the database file is left behind. These files are
described in detail in :doc:`file-format`.

Crash Recovery
--------------

When a statement that changes the database finishes, the pages that it changed
are added to the end of the write-ahead log, which is synced to the disk. This is
the point where the statement is committed. Then the pages are copied into the
database file, which isn't synced, since the log has everything that hasn't
reached the disk yet.

If the process stops before the log is synced, the statement isn't in the log,
so it didn't happen. If it stops after, the statement is copied into the database
file again by the next connection, before it reads or changes the file. Nothing
needs to be done to recover a database: opening it is enough, and it can be
opened by any process (such as ``vsql cli``).

A transaction that was still active when its process stopped is rolled back by a
later connection, when it changes the database and there are no other
connections open to the file (since the transaction might belong to one of
them). Until then, the rows that it changed stay locked. See
:ref:`mvcc:Crashed Transactions`.

A ``COMMIT`` that changes more than one database file (see :doc:`catalogs-and-schemas`)
is committed to each file in turn. If the process stops part way through, the
files that it had reached keep the changes and the rest don't.

Power Failures on macOS
-----------------------

On Linux and Windows, syncing a file waits for the drive to write it to
permanent storage. On macOS, ``fsync`` only hands the data to the drive, which
may keep it in its cache for a while and write it in a different order. So, on
macOS by default:

- A statement that has been committed is never lost if the process stops,
  because the operating system still has the changes.

- A statement that has been committed may be lost if the power fails or the
  operating system stops, and the database file may even be left corrupt.

The ``full_fsync`` connection option (see ``ConnectionOptions`` in
:ref:`language-v:Opening a Connection`) syncs with ``fcntl(F_FULLFSYNC)`` instead, which
also waits for the drive to write its cache:

.. code-block:: v

   mut options := vsql.default_connection_options()
   options.full_fsync = true
   mut db := vsql.open_database('mydb.vsql', options)!

It's off by default because it's much slower: ``vsql bench`` on a file runs 7 to
15 times fewer transactions per second on a Mac (``vsql bench -full-fsync``
measures it, see :doc:`benchmark`). On other systems it's accepted, but doesn't
change anything. It can only be set from V for now. The other commands of the
CLI, ``vsql server`` and the C library (see :doc:`language-c`) always use
``fsync``.

Backups
-------

``vsql out`` writes the schema and data of a database as SQL, which ``vsql in``
loads into a new database (see :ref:`cli:out` and :ref:`cli:in`):

.. code-block:: text

   $ vsql out mydb.vsql > backup.sql
   $ vsql in restored.vsql < backup.sql

``vsql out`` reads each table with its own statement, so if another connection
changes the database while it's running, the tables may come from different
points in time. Run it while nothing else is changing the database to get a
backup that's consistent.

The database file can also be copied, as long as:

- No connection has the file open, or nothing changes it while it's being copied.

- The ``.wal`` file is copied with it, if there is one. There is only a log
  when a connection is open, or when the last process to have the database open
  stopped without closing it.

When a database file is replaced with an older copy (such as when restoring a
backup), any ``.wal`` file next to it must be deleted first, otherwise the
statements in the log would be copied over the restored file the next time it's
opened.
