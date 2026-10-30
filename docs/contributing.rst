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
passes (see :doc:`testing`). CI fails if ``make fmt`` would change anything,
which ``make fmt-verify`` checks.

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

Testing
-------

Most tests are SQL files in ``tests/``. See :doc:`testing`.
