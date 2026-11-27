Language: Rust
==============

`vsql-rust <https://github.com/elliotchance/vsql-rust>`_ is the ``vsql`` crate,
with an API that follows `rusqlite <https://docs.rs/rusqlite>`_. It's built on
libvsql (see :doc:`language-c`), which is compiled into the crate, so there's
nothing else to install.

``Connection::open`` creates the database file if it doesn't exist, and
``Connection::open_in_memory`` is a database that only exists for the life of
the connection. The `documentation <https://docs.rs/vsql>`_ describes
parameters, transactions and the Rust type of each SQL type.

.. contents::

Requirements
------------

Rust 1.75 or later and a C compiler, on macOS (ARM64 and x86-64), Linux (ARM64
and x86-64) or Windows (x86-64). The first build compiles libvsql, which takes
about 30 seconds, after that it's cached by Cargo.

Example
-------

Create a project and add the crate from crates.io:

.. code-block:: sh

   cargo new example && cd example
   cargo add vsql

Replace ``src/main.rs`` with:

.. code-block:: rust

   use vsql::Connection;

   fn main() -> vsql::Result<()> {
       let conn = Connection::open("test.vsql")?;
       conn.execute("CREATE TABLE foo (x INTEGER, y VARCHAR(10))", ())?;
       conn.execute("INSERT INTO foo (x, y) VALUES (?, ?)", (1, "a"))?;

       let mut stmt = conn.prepare("SELECT x, y FROM foo")?;
       for row in stmt.query(())? {
           let row = row?;
           let x: i64 = row.get(0)?;
           let y: String = row.get("y")?;
           println!("{x} {y}");
       }

       Ok(())
   }

Then run it:

.. code-block:: sh

   cargo run

Which creates ``test.vsql`` and prints:

.. code-block:: text

   1 a

The table is in the file, so running it again fails because the table already
exists.
