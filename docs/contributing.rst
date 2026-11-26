Contributing
============

This page is aimed at developers of vsql. Bug reports and ideas are welcome as
`GitHub issues <https://github.com/elliotchance/vsql/issues>`_.

.. contents::

Building from Source
--------------------

vsql is built and tested with the latest V, so update V first with ``v up``.
Then:

.. code-block:: sh

  make bin/vsql       # macOS and linux
  make bin/vsql.exe   # windows

V only generates the C, which is put in ``amalgamation/`` (``make
amalgamation``), and the binary is built from that with the C compiler. It's
built with ``-O2``, which takes about a minute. ``make bin/vsql CFLAGS=-O0``
takes a few seconds, but vsql runs about half as fast, which is fine for most
tests. Since make doesn't rebuild a binary when only ``CFLAGS`` changes, remove
``bin/vsql`` first to switch between them.

Before sending a pull request, run ``make fmt`` and make sure ``make test``
passes (see :doc:`testing`). CI fails if ``make fmt`` would change anything,
which ``make fmt-verify`` checks.

Building Faster
^^^^^^^^^^^^^^^

Everything that ``make`` builds, the binaries and the tests, is optimized the
same way as the binaries that are released, with ``-O2`` from ``CFLAGS``. CI
always builds it that way. The binaries are also built with ``-prod``, but the
tests aren't, since ``-prod`` removes every ``assert``. Building vsql with
``-O2`` takes about a minute, so ``make test`` builds it as few times as it can
(see :doc:`testing`).

While working on a change, run only the tests for it (such as ``TEST=std_11_5_
make sql-test``, see :doc:`testing`), and leave the rest to CI. ``COVERAGE=0``
skips the coverage. ``CFLAGS=-O0`` builds in a fraction of the time, but what's
built runs several times slower, so it's only quicker for something that runs
briefly, such as trying out ``bin/vsql`` or a few unit tests:

.. code-block:: sh

  make bin/vsql CFLAGS=-O0
  v -d vsqltest -cc cc -cflags -O0 test vsql/row_test.v

For the SQL tests, ``-O2`` is quicker, even for a few of them. On an Apple
Silicon Mac, ``TEST=std_11_5_ make sql-test COVERAGE=0`` (1,040 statements)
took 59 seconds with ``-O2`` (45 to build, 14 to run the tests), and 94 seconds
with ``-O0`` (14 to build, 80 to run the tests).

make doesn't build ``bin/vsql`` again when only ``CFLAGS`` changes, so remove
it first to switch between them.

Debugging
---------

Termination signals often don't give much context, you can get more information
by using the ``lldb`` debugger:

.. code-block:: sh

   v examples/memory.v && lldb -o run examples/memory

Documentation
-------------

Documentation is built and published automatically at
`vsql.readthedocs.io <https://vsql.readthedocs.io/en/latest/>`_.

You can generate the documentation locally with:

.. code-block:: sh

   make docs

If you receive an error, you might be missing some dependencies. Install them
in a virtual environment, since some systems have a Pygments that's too old for
Sphinx:

.. code-block:: sh

   python3 -m venv .venv
   . .venv/bin/activate
   pip install -r docs/requirements.txt

Warnings are errors, so fix any that ``make docs`` prints.

``make docs`` will only regenerate the parts that it thinks have changed. To
rebuild the entire docs you can use:

.. code-block:: sh

   make clean-docs docs

``make docs`` also generates ``docs/v-client-library-docs.rst`` from the doc
comments of the V client library. CI runs ``make clean-docs docs`` and fails if
it changed, so commit it with your change.

Parser & SQL Grammar
--------------------

To make changes to the SQL grammar you will need to modify the ``vsql/*.y``
files. These rules are partial or complete BNF rules from the
`2016 SQL standard <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_.

After making changes to grammar file(s) you will need to run:

.. code-block:: sh

  make grammar

``vsql/y.v`` is generated, but it's committed so that ``v install`` works. CI
runs ``make grammar`` and fails if ``vsql/y.v`` changed, so commit it with your
change.

Grammar Conflicts
^^^^^^^^^^^^^^^^^

The grammar must not have any conflicts. A conflict is a point where the
parser could do two different things (shift the next token or reduce a rule,
or reduce one of two rules), and yacc silently picks one of them. ``vsql/grammar.y``
declares ``%expect 0`` (shift/reduce conflicts) and ``%expect-rr 0``
(reduce/reduce conflicts), so ``make grammar`` fails if there are any:

.. code-block:: text

  expected 0 shift/reduce and 0 reduce/reduce conflicts, but there are 0 shift/reduce and 323 reduce/reduce (see %expect)

A conflict is counted once for each token that it happens on, so a single
ambiguous rule can be hundreds of conflicts. To find them, create
``y.output``, which describes every state of the parser:

.. code-block:: sh

  v run scripts/vyacc.v -o /tmp/y.v -v y.output vsql/y.y
  grep conflict y.output

Each conflict names a state, and the state lists the rules that conflict. The
rules in the standard are often ambiguous because the type of an expression
decides how it's parsed. For example, a column on its own could be a
``numeric_primary`` or a ``character_primary``, but the parser can't know the
type of the column. Usually the fix is to make sure that there's only one way
to parse something. ``common_value_expression`` is a good example. It only
contains numeric or string expressions that have an operator or function, a
value on its own is always a ``boolean_value_expression``.

If both choices are always the same and the parser can't know which one it is
from the next token, ``%prec`` can choose one (see ``subquery``). This must be
explained in a comment.

Testing
-------

Most tests are SQL files in ``tests/``. See :doc:`testing`.
