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

Recovering Expired Rows
-----------------------

By its nature MVCC leaves around copies or rows that have either been deleted or
rolled back. These row versions need to exist until at least the transaction is
finished (``COMMIT`` or ``ROLLBACK``). However, in either case, the rows are not
revisited so they will remain invisible to all other future transactions.

This makes the ``COMMIT`` basically zero cost but it requires another process
to clean up expired rows. Since this isn't easily possible or ideal for a
single-process database, vsql performs cleanup on ``COMMIT`` and ``ROLLBACK``
which on any pages that were modified during the transaction.

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
connection to the database is open.

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
