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

Testing
-------

Most tests are SQL files in ``tests/``. See :doc:`testing`.
