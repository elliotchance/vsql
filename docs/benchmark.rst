Benchmark
=========

The main focus of vsql is on compatibility and features of the SQL standard.
That does not mean that speed is not important, but less important since there
are already a wide array of products out there that are battled tested and tuned
to perfection. This page is useful to compare the relative performance
improvements between releases.

Use the follow command to run the on-disk and memory benchmarks:

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

A transaction consists of 5 statements (in order):

1. ``UPDATE accounts SET abalance = abalance + :delta WHERE aid = :aid``
2. ``SELECT abalance FROM accounts WHERE aid = :aid``
3. ``UPDATE tellers SET tbalance = tbalance + $delta WHERE tid = :tid``
4. ``UPDATE branches SET bbalance = bbalance + $delta WHERE bid = :bid``
5. ``INSERT INTO history (tid, bid, aid, delta, mtime) VALUES (:tid, :bid, :aid, :delta, CURRENT_TIMESTAMP)``

Where ``:aid``, ``:tid`` and ``:bid`` are random integers that are within the
their respective ranges and ``:delta`` is a random value between -5000 and 5000.

After the benchmark is finished it will report something like:

.. code-block:: txt

   INSERT: 100000 rows in 19.692 (5078.086 rows/s)
   SELECT: 100000 rows in 0.845 (118389.150 rows/s)
   TCP-B (sort of): 25 transactions in 61.963 (0.403 transactions/s)

Where:

- ``INSERT`` describes the raw INSERT rate into the largest table ``ACCOUNTS``.
- ``SELECT`` describes the raw SELECT read rate with a simple filter (``aid = 0``). This will not match any records but it will ensure the entire table is read.
- ``TCP-B (sort of)`` is the result from the test explained above.

Notes
-----

1. It may look initially suspicious that the ``INSERT`` and ``SELECT`` speeds
seem reasonable but ``TCP-B (sort of)`` is extremely slow. This is because vsql
does not have any indexes yet, so each transaction is effectievly reading all
rows 4 times. This will be substantially improved in the future.

2. ``CURRENT_TIMESTAMP`` is not yet supported, so a V generated timestamp as
``VARCHAR`` is used instead.

3. ``INSERT`` only inserts one row per statement (rather than bulk inserts with
a single statement). Bulk inserts are not yet supported, although when they are
this mechanic will probably not change.

4. The ``bench`` command will create a file called ``bench.vsql`` for the test.
If the file already exists the command will fail as it tries to create tables
that already exist. You must delete ``bench.vsql`` between test runs.

Results
-------

These were run on:

- MacBook Pro (Retina, 15-inch, Late 2013)
- 2.3 GHz Quad-Core Intel Core i7
- 16 GB 1600 MHz DDR3

**INSERT** and **SELECT** are in rows per second and **TCP-B** is in transactions per second.

+------------+---------+-------------------------+-------------------------+-------+
|            |         | On-disk                 | In-memory               |       |
| Date       | Version +--------+--------+-------+--------+--------+-------+ Notes |
|            |         | INSERT | SELECT | TCP-B | INSERT | SELECT | TCP-B |       |
+============+=========+========+========+=======+========+========+=======+=======+
| 2021-10-04 | v0.14.2 | 974    | 65775  | 97    | 939    | 64267  | 97    | [5]_  |
+------------+---------+--------+--------+-------+--------+--------+-------+-------+
| 2021-09-19 | v0.14.0 | 995    | 61782  | 94    | 992    | 62253  | 91    | [4]_  |
+------------+---------+--------+--------+-------+--------+--------+-------+-------+
| 2021-09-15 | v0.12.1 | 378    | 65256  | 0.376 | 270    | 71851  | 0.396 | [3]_  |
+------------+---------+--------+--------+-------+--------+--------+-------+-------+
| 2021-09-15 | v0.12.0 | 355    | 71851  | 0.377 |        |        |       | [2]_  |
+------------+---------+--------+--------+-------+--------+--------+-------+-------+
| 2021-09-04 | v0.11.0 | 5107   | 129252 | 0.378 |        |        |       | [1]_  |
+------------+---------+--------+--------+-------+--------+--------+-------+-------+

.. [5] The recent two patches focused on fixes to do with concurrent read/write
   to the same file. This is critical general reliability and for transactions
   (coming soon). Fortunately, the added locking mechanics did not have any
   serious impact on performance. Which is a bit surprising since readers and
   writers have to always check if the schema has changed on the file
   underneath. Or, perhaps, it was just some inadvertent optimizations that were
   introduced when simplifying the abstraction layers and lifecycle between
   Connection/Storage/Btree/Pager/File.

.. [4] Now we can utilize a PRIMARY KEY on the table which the query planner
   understands for exact matches (which we use in these benchmarks). This
   creates an enourmous speed up since we only need to check pages that contain
   the record.

.. [3] This version introduces an in-memory option, but no changes were made to
   functionality. The on-disk and in-memory performance is similar because the
   OS does a very good job at cashing random access reads and writes.

.. [2] This version completely replaces the storage engine with with a B-tree on
   disk. Although the ``INSERT`` and ``SELECT`` speeds are much lower, the same
   transaction throughput is retained because it no longer has to scan the full
   file for any ``SELECT`` operation. The current implementation uses a 4kb
   page, but leaves a lot of low hanging fruit for optimization, however, this
   version only focused on functionalty and not performance.

.. [1] This first version of the storage format is basically a binary CSV. Where
   tables and rows are treated as objects in a stream. That is, to find a record
   is to read (and decode) all rows from every table.
