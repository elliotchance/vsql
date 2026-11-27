Embedding
=========

vsql can be embedded in a program, so there's no server to run. C and C++
programs use libvsql, the SQL/CLI library, and the libraries for the other
languages (except V) are built on it:

- :doc:`V <language-v>`: the ``vsql`` module (with V's ORM).
- :doc:`C/C++ <language-c>`: the SQL/CLI routines.
- :doc:`Go <language-go>`: a ``database/sql`` driver.
- :doc:`Python <language-python>`: a DB-API 2.0 (PEP 249) driver.
- :doc:`Java <language-java>`: a JDBC driver.
- :doc:`Rust <language-rust>`: a crate with an API like rusqlite.
- :doc:`Node.js <language-node>`: a synchronous driver like better-sqlite3.
- :doc:`Swift <language-swift>`: a package that can decode rows as ``Decodable``.

From V, you can also add your own SQL functions (see :doc:`custom-functions`)
and tables backed by your own code (see :doc:`virtual-tables`). From C, SQL can
also be written in :doc:`SQL-client modules <sql-client-modules>` or embedded
in the C source (see :doc:`embedded-sql-c`).

.. toctree::
   :maxdepth: 1

   custom-functions.rst
   embedded-sql-c.rst
   sql-client-modules.rst
   virtual-tables.rst
   language-c.rst
   language-go.rst
   language-java.rst
   language-node.rst
   language-python.rst
   language-rust.rst
   language-swift.rst
   language-v.rst
