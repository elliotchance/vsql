MVCC
====

vsql transactions are implemented using Multiversion Concurrency Control (MVCC).
In a nutshell, MVCC maintains multiple copies of rows that are visible to
respective transactions. MVCC is one method to ensure readers and writers do not
block readers or writers.

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

Wraparound Transaction IDs
--------------------------

Another challange with MVCC is that it requires transactions IDs to increment.
Eventually vsql will run out of transaction IDs leading to incorrect behavior.
See https://github.com/elliotchance/vsql/issues/70.

Resources
---------

1. `Multiversion concurrency control - Wikipedia <https://en.wikipedia.org/wiki/Multiversion_concurrency_control>`_.
2. `Implementing Your Own Transactions with MVCC - Elliot Chance <https://levelup.gitconnected.com/implementing-your-own-transactions-with-mvcc-bba11cab8e70>`_.
3. `The Internals of PostgreSQL, Chapter 5: Concurrency Control <http://www.interdb.jp/pg/pgsql05.html>`_.
