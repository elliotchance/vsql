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

Usage
-----

.. code-block:: sh

   vsql bench                                       # in memory
   vsql bench -file bench.vsql                      # on disk, in bench.vsql
   vsql bench -size 10                              # 10 times the rows
   vsql bench -duration 5                           # a quicker test
   vsql bench -isolation read-committed             # READ COMMITTED transactions
   vsql bench -file bench.vsql -suite tpc-b-setup   # only insert the rows
   vsql bench -file bench.vsql -suite tpc-b-oltp    # only run the transactions
   vsql bench -file bench.vsql -suite tpc-b-check   # only check the rows and totals

The options are:

- ``-memory``: Run the benchmark in memory. This is the default, so it's only
  needed to be explicit. It can't be used with ``-file``.

- ``-file``: Run the benchmark on disk, in this file, which is created if it
  doesn't exist. It can be an existing database, since the benchmark only uses
  its own schema (see *Schema*). It can't be used with ``-memory``.

- ``-suite``: What to run (see *Suites*):

  - ``tpc-b``: All three of the suites below, in order (the default).
  - ``tpc-b-setup``: Create the tables and insert the rows.
  - ``tpc-b-oltp``: Run the transactions.
  - ``tpc-b-check``: Check the rows and totals.

- ``-size``: Multiplies the number of rows of each table (see *Process*), like
  the scale factor of pgbench. The default is 1, and ``-size 10`` creates
  1,000,000 accounts, 100 tellers and 10 branches. It can't be used with the
  ``tpc-b-oltp`` or ``tpc-b-check`` suites, which use the size of the tables in
  the file.

- ``-duration``: The number of seconds to run transactions for (default 60).

- ``-isolation``: The isolation level of each transaction: ``read-committed``,
  ``repeatable-read`` or ``serializable`` (the default). Since there's only one
  connection, this measures the cost of the isolation level itself (see
  :doc:`transactions`). ``read-uncommitted`` can't be used, because it's always
  ``READ ONLY`` (it runs the same way as ``read-committed`` anyway).

- ``-full-fsync``: Use ``F_FULLFSYNC`` to sync the file on macOS (see
  ``full_fsync`` in :doc:`v-client-library-docs`). It makes no difference on
  other systems, or with ``-memory``.

Suites
------

``-suite`` chooses what the benchmark runs:

- ``tpc-b-setup`` creates the ``TPC_B`` schema and its tables, and inserts the
  rows (steps 1 to 5 of *Process*). It fails if the ``TPC_B`` schema already
  exists.

- ``tpc-b-oltp`` reads every account and then runs the transactions (step 6 of
  *Process*) on a file that ``tpc-b-setup`` created. It needs ``-file``, since a
  new in-memory database wouldn't have any rows.

- ``tpc-b-check`` checks that ``ACCOUNTS``, ``TELLERS`` and ``BRANCHES`` have
  the number of rows that ``tpc-b-setup`` inserted, and that the balances of
  each table add up to the total of the deltas in ``HISTORY``. Every
  transaction adds its delta to one row of each table, so the totals would only
  be different if a transaction was lost, partly applied or applied more than
  once. If a check fails, it stops with an error that says what's wrong. Like
  ``tpc-b-oltp``, it needs ``-file``.

- ``tpc-b`` (the default) runs ``tpc-b-setup``, ``tpc-b-oltp`` and then
  ``tpc-b-check``.

Running the suites separately means the rows only need to be inserted once, and
the transactions can then be run (and measured) as many times as needed:

.. code-block:: sh

   vsql bench -file bench.vsql -suite tpc-b-setup -size 10
   vsql bench -file bench.vsql -suite tpc-b-oltp
   vsql bench -file bench.vsql -suite tpc-b-oltp -isolation read-committed
   vsql bench -file bench.vsql -suite tpc-b-check

Each ``tpc-b-oltp`` adds rows to the ``HISTORY`` table and changes the
balances, so the runs after the first one aren't on exactly the same data.

Schema
------

The tables are created in their own ``TPC_B`` schema, so the benchmark can be
run on an existing database without touching any of its other tables. The
suites never delete a file or drop anything. When the benchmark tables aren't
needed any more, drop them with:

.. code-block:: sql

   DROP SCHEMA tpc_b CASCADE;

``tpc-b-setup`` (and ``tpc-b``) fail if the ``TPC_B`` schema already exists,
rather than adding to (or replacing) tables that are already there. To run the
setup again on the same file, drop the schema first. ``make bench`` deletes its
``bench.vsql`` file before each run.

Process
-------

The ``tpc-b`` suite runs a TPC-B-like transactional test that is inspired by
(copied from)
`PostgreSQL's pgbench tool <https://www.postgresql.org/docs/current/pgbench.html>`_.
And executes the following (where *size* is ``-size``):

1. Create the ``TPC_B`` schema.
2. Create an ``ACCOUNTS`` table with 100,000 rows for each *size*.
3. Create a ``TELLERS`` table with 10 rows for each *size*.
4. Create a ``BRANCHES`` table with one row for each *size*.
5. Create a ``HISTORY`` table that is empty.
6. Will run as many transactions as it can within 60 seconds (``-duration``).

A transaction consists of 7 statements (in order):

1. ``START TRANSACTION`` (with ``ISOLATION LEVEL`` if ``-isolation`` is used)
2. ``UPDATE tpc_b.accounts SET abalance = abalance + <delta> WHERE aid = <aid>``
3. ``SELECT abalance FROM tpc_b.accounts WHERE aid = <aid>``
4. ``UPDATE tpc_b.tellers SET tbalance = tbalance + <delta> WHERE tid = <tid>``
5. ``UPDATE tpc_b.branches SET bbalance = bbalance + <delta> WHERE bid = <bid>``
6. ``INSERT INTO tpc_b.history (tid, bid, aid, delta, mtime) VALUES (<tid>, <bid>, <aid>, <delta>, CURRENT_TIMESTAMP)``
7. ``COMMIT``

Where ``<aid>``, ``<tid>`` and ``<bid>`` are random integers that are within
their respective ranges and ``<delta>`` is a random value between -5000 and 5000.

Output
------

The output is one ``name=value`` line for each setting and result, with a
``#`` heading for each suite that ran. For example, ``vsql bench`` reports
something like:

.. code-block:: text

   # vsql bench
   version=v1.5.0
   version_date=2026-12-01
   suite=tpc-b
   file=:memory:
   size=1
   duration_seconds=60
   isolation=serializable

   # tpc-b-setup
   insert_rows=100000
   insert_seconds=12.588
   insert_rows_per_second=7943.792

   # tpc-b-oltp
   select_rows=100000
   select_seconds=0.169
   select_rows_per_second=593127.286
   transactions=42341
   transactions_seconds=60.001
   transactions_per_second=705.672
   serialization_failures=0

   # tpc-b-check
   check_history_rows=42341
   check_total=-66522
   check_seconds=0.490

   peak_memory_mib=253.4

Where:

- ``version`` and ``version_date`` are the version of vsql (empty if it wasn't
  built for a release), and ``suite``, ``file`` and ``size`` are the options
  (``size`` is read from the file for ``tpc-b-oltp`` and ``tpc-b-check``).
  ``duration_seconds`` and ``isolation`` are only shown when the transactions
  run.
- ``insert_*`` is the raw INSERT rate into the largest table, ``ACCOUNTS``.
- ``select_*`` is the raw SELECT read rate with a simple filter
  (``abalance = 0``), which reads the entire table.
- ``transactions*`` is the result from the transactions explained above, only
  counting the ones that were committed.
- ``serialization_failures`` is the number of transactions that failed with a
  ``40001`` serialization failure, because of a transaction on another
  connection (see :doc:`transactions`). Each one was rolled back, and the
  benchmark carried on with the next one.
- ``check_history_rows`` is the number of rows in ``HISTORY`` (every
  transaction that has ever run on the file) and ``check_total`` is the total
  of their deltas, which all the balances added up to.
- ``peak_memory_mib`` is the most memory (resident set size) that the process
  used for the whole benchmark, in MiB. It's sampled while the benchmark runs,
  so a short spike between samples may not be seen. It isn't shown on a
  platform that can't report it.

Every name is only used once, and a value is quoted (like a shell would) if it
has spaces or other special characters, so the output can be read by a script.
For example, to get one value:

.. code-block:: sh

   vsql bench -duration 5 | grep '^transactions_per_second=' | cut -d= -f2

Or to load them all as shell variables (the ``#`` lines are comments):

.. code-block:: sh

   source <(vsql bench -duration 5)
   echo "$transactions_per_second"

Errors (including a failed check) are written to stderr, and the exit code is
not 0.

Notes
-----

1. ``INSERT`` only inserts one row per statement (rather than inserting many
rows with a single statement).

2. The benchmark only uses one connection. Benchmarks with several connections
at the same time are run from separate processes, each with its own
``tpc-b-oltp`` on the same ``-file``. ``make concurrency-test`` does that (see
:doc:`testing`).

3. As the pgbench documentation says, don't trust a benchmark that only runs for
a few seconds. Run it for at least a minute (the default), and run it more than
once to see how much the results change.
