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

.. toctree::
   :maxdepth: 1

   language-v.rst
   custom-functions.rst
   virtual-tables.rst
   language-c.rst
   sql-client-modules.rst
   embedded-sql-c.rst
   language-go.rst
   language-python.rst
   language-java.rst
   language-rust.rst
   language-node.rst
   language-swift.rst
