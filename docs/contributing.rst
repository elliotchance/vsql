Contributing
============

This page is aimed to developers of vsql.

.. contents::

Building from Source
--------------------

.. code-block:: sh

  make bin/vsql       # macOS and linux
  make bin/vsql.exe   # windows

Debugging
---------

Termination signals often don't give much context, you can get more information
by using the ``lldb`` debugger:

.. code-block:: sh

   v examples/memory.v && lldb -o run examples/memory

Documentation
-------------

Documentation is built and published automatically at
`vsql.readthedocs.com <https://vsql.readthedocs.io/en/latest/>`_.

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

To make changes to the SQL grammar you will need to modify the ``*.y`` files.
These rules are partial or complete BNF rules from the
`2016 SQL standard <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_.

After making changes to grammar file(s) you will need to run:

.. code-block:: sh

  make grammar

Testing
-------

vsql is tested exclusively with SQL test files. See :doc:`testing`.
