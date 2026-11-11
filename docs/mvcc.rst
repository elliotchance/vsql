MVCC
====

vsql transactions are implemented using Multiversion Concurrency Control (MVCC).
In a nutshell, MVCC maintains multiple copies of rows that are visible to
respective transactions. MVCC is one method to ensure that a transaction doesn't
block other readers or writers until it finishes. Each statement still locks the
database file while it runs (a shared lock to read, or an exclusive lock to
write), but only for the duration of that statement.

At most 256 transactions can be active at the same time, because their IDs are
kept in the header of the database file (see :doc:`file-format`). Starting
another one is an error ``0B000``.

A transaction is only given an ID by its first statement that changes the
database. Until then, each statement reads the rows that are committed, like a
statement on its own, and the transaction doesn't lock the file for writing or
change it. So a transaction that only reads works on a database that can only
be read, such as one that needs a newer version of vsql to be changed (see
:doc:`file-format`). Its isolation level still applies from when it starts (see
*Isolation Levels* in :doc:`transactions`).

A ``REPEATABLE READ`` transaction is given its ID when it starts instead, so
that it can publish its snapshot (see *Snapshots*). If the database can only be
read, it can't be, so it starts without one. Since a ``COMMIT`` may remove a
version of a row that it would have seen, each of its statements then fails with
a ``40001`` if a transaction has ended since it started, until it changes the
database and takes its snapshot.

Snapshots
---------

A ``READ COMMITTED`` or ``SERIALIZABLE`` statement uses the *Active
Transactions* in the header, which is read again for every statement, so it
sees the rows that were committed before the statement started.

A ``REPEATABLE READ`` transaction takes a snapshot when it starts instead:
its own transaction ID and the other active transactions. A version of a row
is visible if the transaction that created it had committed by then (it has a
lower ID and wasn't active) and the transaction that expired it (if any)
hadn't. The snapshot is kept in memory, so other connections can commit, and
change the header, while the transaction is active.

The first committer wins: updating or deleting a version of a row that another
transaction has expired, or creating a row that another transaction has
created, since the snapshot was taken fails with a ``40001``. A ``FOREIGN KEY``,
a ``UNIQUE`` or ``PRIMARY KEY`` constraint, and a change to the schema are
checked the same way. The schema itself is loaded for the snapshot while the
transaction is active, so a table that was created later isn't seen.

Transaction IDs give the order transactions started, not the order they
committed, so a snapshot can still see a version that was expired by any
transaction that commits after it started. The snapshot is published in the
file as a Snapshot Object (see :doc:`file-format`), so that a ``COMMIT`` in
any process can find the versions that it must keep. Each kept version gets a
Retained Version Object, and is removed when the last snapshot that can see it
ends. Since a row can only have two versions, another transaction can't change
a kept row again until then (it gets a ``40001``).

Recovering Expired Rows
-----------------------

By its nature MVCC leaves around copies or rows that have either been deleted or
rolled back. These row versions need to exist until at least the transaction is
finished (``COMMIT`` or ``ROLLBACK``). However, in either case, the rows are not
revisited so they will remain invisible to all other future transactions.

This makes the ``COMMIT`` basically zero cost but it requires another process
to clean up expired rows. Since this isn't easily possible or ideal for a
single-process database, vsql performs cleanup on ``COMMIT`` and ``ROLLBACK``
which on any pages that were modified during the transaction. The exception is
a version that a ``REPEATABLE READ`` transaction can still see, which is
removed when that transaction ends (see `Snapshots`_).

The cost of a ``COMMIT`` or ``ROLLBACK`` should be approximately equal to each
other. However, the cost of an individual ``COMMIT`` or ``ROLLBACK`` is
proportional to the amount of pages modified and not the number of changes
directly.

Crashed Transactions
--------------------

If a process dies in the middle of a transaction (it crashes or is killed) its
transaction stays in the active list of the file header, and the rows it changed
would be locked forever.

Every connection to a database file holds a shared lock on a second file, with
the same name followed by ``.session``, for as long as the connection is open.
The operating system releases this lock when a process dies. When a connection
writes to the database and it is the only connection with the session lock, any
other active transaction must belong to a connection that no longer exists, so
those transactions are rolled back.

This means that a crashed transaction will not be rolled back while any other
connection to the database is open. A crashed ``REPEATABLE READ`` transaction
also keeps the versions of rows that its snapshot can see until then.

Wraparound Transaction IDs
--------------------------

Another challenge with MVCC is that it requires transactions IDs to increment.
Some databases use 32-bit transaction IDs, which can run out and have to wrap
around. vsql uses 64-bit transaction IDs, so even at one million transactions
per second a database would take more than 500,000 years to run out. Transaction
IDs never wrap around.

Resources
---------

1. `Multiversion concurrency control - Wikipedia <https://en.wikipedia.org/wiki/Multiversion_concurrency_control>`_.
2. `Implementing Your Own Transactions with MVCC - Elliot Chance <https://levelup.gitconnected.com/implementing-your-own-transactions-with-mvcc-bba11cab8e70>`_.
3. `The Internals of PostgreSQL, Chapter 5: Concurrency Control <http://www.interdb.jp/pg/pgsql05.html>`_.
