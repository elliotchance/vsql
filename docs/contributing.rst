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

Before sending a pull request, run ``make fmt`` and make sure ``make test``
passes (see :doc:`testing`).

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

If you receive an error, you might be missing some dependencies:

.. code-block:: sh

   pip3 install sphinx sphinx_rtd_theme
   cd docs && python3 -m pip install -r requirements.txt

``make docs`` will only regenerate the parts that it thinks have changed. To
rebuild the entire docs you can use:

.. code-block:: sh

   make clean-docs docs

Parser & SQL Grammar
--------------------

To make changes to the SQL grammar you will need to modify the ``vsql/*.y``
files. These rules are partial or complete BNF rules from the
`2016 SQL standard <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_.

After making changes to grammar file(s) you will need to run:

.. code-block:: sh

  make grammar

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
