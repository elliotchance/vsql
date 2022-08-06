Command Line Interface (CLI)
============================

You can also work with database files through the CLI (ctrl+c to exit):

.. code-block:: text

   $ vsql test.vsql
   vsql> select * from foo
   A: 1234 
   1 row (1 ms)

   vsql> select * from bar
   0 rows (0 ms)

Binary releases can be downloaded from the
`Releases <https://github.com/elliotchance/vsql/releases>`_ page (under Assets).

These binary releases do not require V to be installed. Or, you can compile from
source with:

.. code-block:: sh

   make bin/vsql       # macOS and linux
   make bin/vsql.exe   # windows
