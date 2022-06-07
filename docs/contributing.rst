Contributing
============

This page is aimed to developers of vsql.

.. contents::

Building from Source
--------------------

.. code-block:: sh

  make vsql

Debugging
---------

Termination signals often don't give much context, you can get more information
by using the ``lldb`` debugger:

.. code-block:: sh

   v examples/memory.v && lldb -o run examples/memory

Parser & SQL Grammar
--------------------

To make changes to the SQL grammar you will need to modify the ``grammar.bnf``
file. These rules are partial or complete BNF rules from the
`2016 SQL standard <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_.

Within ``grammar.bnf`` you will see that some of the rules have a parser
function which is a name after ``->``. The actual parser function will have
``parse_`` prefix added. You can find all the existing parse functions in the
``parse.v`` file.

If a rule does not have a parse function (no ``->``) then the value will be
passed up the chain which is the desired behavior in most cases. However, be
careful if there are multiple terms, you will need to provide a parse function
to return the correct term.

Each of the rules can have an optional type described in ``/* */`` before
``::=``. Rules that do not have a type will be ignored as parameters for parse
functions. Otherwise, these types are used in the generated code to make sure
the correct types are passed into the parse functions.

After making changes to ``grammar.bnf`` you will need to run:

.. code-block:: sh

  make grammar

Now, when running `v test .` you may receive errors for missing ``parse_``
functions, you should implement those now.

Testing
-------

vsql is tested exclusively with SQL test files. See :doc:`testing`.
