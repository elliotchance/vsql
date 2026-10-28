Benchmark
=========

The main focus of vsql is on compatibility and features of the SQL standard.
That does not mean that speed is not important, but less important since there
are already a wide array of products out there that are battle tested and tuned
to perfection. The benchmark is useful to compare the relative performance of
two versions, or of a change.

Use the following command to run the on-disk and memory benchmarks:

.. code-block:: sh

   make bench

.. contents::

Process
-------

With the default (no options) ``vsql bench`` runs a TPC-B-like transactional
test that is inspired by (copied from)
`PostgreSQL's pgbench tool <https://www.postgresql.org/docs/current/pgbench.html>`_.
And executes the following:

1. Create an ``ACCOUNTS`` table with 100,000 rows.
2. Create a ``TELLER`` table with 10 rows for each branch.
3. Create a ``BRANCH`` table with one row for each connection (see
   *Connections*).
4. Create a ``HISTORY`` table that is empty.
5. Will run as many transactions as it can within 60 seconds.

A transaction consists of 7 statements (in order):

1. ``START TRANSACTION``
2. ``UPDATE accounts SET abalance = abalance + :delta WHERE aid = :aid``
3. ``SELECT abalance FROM accounts WHERE aid = :aid``
4. ``UPDATE tellers SET tbalance = tbalance + :delta WHERE tid = :tid``
5. ``UPDATE branches SET bbalance = bbalance + :delta WHERE bid = :bid``
6. ``INSERT INTO history (tid, bid, aid, delta, mtime) VALUES (:tid, :bid, :aid, :delta, CURRENT_TIMESTAMP)``
7. ``COMMIT``

Where ``:aid``, ``:tid`` and ``:bid`` are random integers that are within
their respective ranges and ``:delta`` is a random value between -5000 and 5000.

A transaction that fails with a ``40001`` serialization failure has been rolled
back, so it's counted separately and the connection moves on to the next one.

After the benchmark is finished it will report something like:

.. code-block:: text

   100000 accounts, 10 tellers, 1 branches, 1 connections
   INSERT: 100000 rows in 19.692 (5078.086 rows/s)
   SELECT: 100000 rows in 0.845 (118389.150 rows/s)
   TPC-B (sort of): 25 transactions in 61.963 (0.403 transactions/s)

Where:

- ``INSERT`` describes the raw INSERT rate into the largest table ``ACCOUNTS``.
- ``SELECT`` describes the raw SELECT read rate with a simple filter (``aid = 0``). This will not match any records but it will ensure the entire table is read.
- ``TPC-B (sort of)`` is the result from the test explained above. Only the
  transactions that were committed are counted. If any failed with ``40001``,
  they're reported on another line.

Connections
-----------

``-connections`` runs the transactions from several connections at the same
time, each in its own thread, such as ``vsql bench -connections 10``. It can only
be used with a file.

With the default isolation level (``SERIALIZABLE``), only one transaction can
change the database at a time, so the others wait for it (see
:doc:`transactions`). With ``-isolation read_committed`` they run at the same
time, but every transaction updates one row in ``BRANCHES``, and two
transactions can't change the same row at the same time. With fewer branches
than connections, most of the transactions would fail with ``40001``, and the
benchmark would mostly be measuring that. Like pgbench, the *scale* (the number of branches, with 10
tellers for each branch) is the number of connections by default, and it should
never be less. ``-scale`` sets it explicitly, such as
``vsql bench -connections 10 -scale 100``.

Unlike pgbench, ``-scale`` doesn't change the number of accounts (which pgbench
multiplies by the scale), because inserting them is slow. There are so many
accounts that two transactions rarely change the same one anyway.

As the pgbench documentation says, don't trust a benchmark that only runs for a
few seconds. Run it for at least a minute (the default), and run it more than
once to see how much the results change.

Notes
-----

1. A timestamp generated in V is stored as a ``VARCHAR``, rather than using
``CURRENT_TIMESTAMP``.

2. ``INSERT`` only inserts one row per statement (rather than inserting many
rows with a single statement).

3. The ``bench`` command will create a file called ``bench.vsql`` for the test.
If the file already exists it's deleted first. Use ``-file`` to choose another
file, or ``-file ':memory:'`` to run it in memory.

4. ``-accounts`` changes the number of rows in the ``ACCOUNTS`` table and
``-duration`` changes how many seconds the transactions are run for, such as
``vsql bench -accounts 1000 -duration 5`` for a quick test.

5. ``-isolation`` sets the isolation level of each transaction, such as
``vsql bench -isolation read_committed``. With one connection, this only
measures the cost of the isolation level itself. Use ``-connections`` to include the
transactions that it stops from committing (see :doc:`transactions`).
``READ UNCOMMITTED`` runs the same way as ``READ COMMITTED``.
