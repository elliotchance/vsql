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
`PostgreSQL's pgbench tool <https://www.postgresql.org/docs/10/pgbench.html>`_.
And executes the following:

1. Create an ``ACCOUNTS`` table with 100,000 rows.
2. Create a ``TELLER`` table with 10 rows.
3. Create a ``BRANCH`` table with a single row.
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

After the benchmark is finished it will report something like:

.. code-block:: text

   INSERT: 100000 rows in 19.692 (5078.086 rows/s)
   SELECT: 100000 rows in 0.845 (118389.150 rows/s)
   TPC-B (sort of): 25 transactions in 61.963 (0.403 transactions/s)

Where:

- ``INSERT`` describes the raw INSERT rate into the largest table ``ACCOUNTS``.
- ``SELECT`` describes the raw SELECT read rate with a simple filter (``aid = 0``). This will not match any records but it will ensure the entire table is read.
- ``TPC-B (sort of)`` is the result from the test explained above.

Notes
-----

1. A timestamp generated in V is stored as a ``VARCHAR``, rather than using
``CURRENT_TIMESTAMP``.

2. The rows are loaded with ``INSERT`` statements that insert up to 1000 rows
each (rather than with ``COPY``).

3. The ``bench`` command will create a file called ``bench.vsql`` for the test.
If the file already exists it's deleted first. Use ``-file`` to choose another
file, or ``-file ':memory:'`` to run it in memory.

4. ``-accounts`` changes the number of rows in the ``ACCOUNTS`` table and
``-duration`` changes how many seconds the transactions are run for, such as
``vsql bench -accounts 1000 -duration 5`` for a quick test.
