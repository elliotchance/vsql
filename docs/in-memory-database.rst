In-Memory Database
==================

Opening a database with the special file name ``:memory:`` will use an entirely
in-memory database. Nothing is written to disk, and the database is gone when
the connection is closed:

.. code-block:: v

   mut db := vsql.open(':memory:')!

The CLI accepts it as well:

.. code-block:: sh

   vsql cli :memory:

The name of the catalog (see :doc:`catalogs-and-schemas`) is ``:memory:``.

.. contents::

Connections
-----------

Each ``vsql.open(':memory:')`` is a new, empty database, even in the same
program. An in-memory database only belongs to the connection that opened it,
so it can't be shared with another connection:

.. code-block:: v

   mut a := vsql.open(':memory:')!
   mut b := vsql.open(':memory:')!

   a.query('CREATE TABLE t (x INTEGER)')!
   b.query('SELECT * FROM t')! // 42P01: no such table: ":memory:".PUBLIC.T

So with ``vsql server :memory:``, each client that connects has its own empty
database, which is gone when it disconnects. ``vsql app`` can't use ``:memory:``
at all, since it opens the files again for each request (see :doc:`app`).

The database is gone when the connection is closed (or the program ends). Use
``dump()`` (see :ref:`language-v:Dumping a Database`) to save it as SQL first, if it's needed.

Transactions
------------

Transactions work the same as they do for a file, so a ``ROLLBACK`` (or a
statement that fails) undoes its changes, see :doc:`transactions`. Since no
other connection can use the database, a transaction never has to wait for
another one.

Options
-------

The ``page_size`` of the ``ConnectionOptions`` (see :doc:`language-v`) is used
for an in-memory database, and it's checked when it's opened: a size that's 16
or less, or more than 65535, is an error ``54000``, and so is a page that's too
small for what's stored in it (such as 17 bytes). The options that are about the
file, such as ``cache_size`` and ``full_fsync``, don't do anything.

In-Memory Catalogs
------------------

An in-memory database can also be added to a connection as another catalog, such
as for temporary tables that are kept next to a database file. It's created with
its ``PUBLIC`` schema, and is gone when the connection is closed:

.. code-block:: v

   mut db := vsql.open('shop.vsql')!
   db.add_catalog('scratch', ':memory:', vsql.default_connection_options())!

   db.query('CREATE TABLE "scratch".public.tmp (x INTEGER)')!
   db.query('INSERT INTO "scratch".public.tmp VALUES (5)')!
