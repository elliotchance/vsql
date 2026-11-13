PostgreSQL Server
=================

vsql can be run as a server and any PostgreSQL-compatible driver can access it.
This is ideal if you want to use a more familiar or feature rich database
client.

See the :doc:`list of supported clients here<postgresql-clients>`.

Start it with a database file (if the file does not exist it will be created):

.. code-block:: text

   $ vsql server mydb.vsql
   ready on 127.0.0.1:3210

vsql will ignore any authentication values (such as user, password, database,
etc). Simply connect using ``127.0.0.1:3210``. Use ``-port`` to listen on a
different port, see :doc:`cli`.

By default, the server only listens on ``127.0.0.1``, so only clients on the
same machine can connect. Use ``-host`` to listen on another address, such as
``0.0.0.0`` (every IPv4 interface) or ``::`` (every interface):

.. code-block:: text

   $ vsql server -host :: mydb.vsql
   ready on [::]:3210

.. warning::

   The server doesn't check passwords, so when it listens on an address that
   other machines can reach, anyone who can connect to the port can read and
   change the database. Only do this on a trusted network, or block the port
   with a firewall.

The server is for PostgreSQL clients, so it isn't direct invocation of SQL (see
:doc:`cli`). Like PostgreSQL, a statement that isn't inside a
:doc:`start-transaction` runs in a transaction of its own, which is committed
when the statement finishes. A client that disconnects in the middle of a
transaction rolls it back.

Many PostgreSQL clients send a ``SELECT`` without a ``FROM`` (such as
``SELECT 1``), which isn't valid SQL. ``vsql server`` runs these as if they had
``FROM singlerow``, a table with a single row.

PostgreSQL clients also set PostgreSQL's run-time parameters, such as
``SET LOCAL search_path TO public``. ``vsql server`` replies ``SET`` to any
``SET [ SESSION | LOCAL ] <name> { TO | = } ...`` without running it. A ``SET``
in the SQL standard, such as ``SET SCHEMA``, still runs.

Clients also read PostgreSQL's system catalog to list the schemas and tables.
Each connection of a client (but no other connection) has the parts of it that
clients use, which are flagged as ``V5XX`` (see :doc:`sql-flagging`):
``pg_namespace``, ``pg_class`` and ``pg_statio_user_tables`` (from the schemas and tables of the
database), an empty ``pg_type``, ``pg_enum`` and ``pg_proc``, and the
``pg_get_userbyid()``, ``pg_get_function_identity_arguments()``,
``obj_description()``, ``pg_total_relation_size()``, ``pg_table_size()`` and
``pg_indexes_size()`` functions (there are no comments, and the sizes are
``NULL``). ``vsql server`` also accepts the PostgreSQL syntax that clients use
in these queries: it removes ``pg_catalog.`` before a name (the catalog is in
the default schema), runs a cast such as ``reltuples::int8`` as a ``CAST``, and
runs a ``NULL`` column of a select list (such as ``SELECT NULL AS size``) as a
``BIGINT``. Like PostgreSQL, it sends the name of a column in lower case if it
has no lower case letters, so ``SELECT relname AS name`` has a ``name`` column.

Any number of clients can be connected at the same time (although no more than
256 can be in a transaction at once). Each client has its own
connection, so a transaction started by one client is not visible to the others
until it is committed. A client that disconnects during a transaction will have
that transaction rolled back.

Embedding the Server
--------------------

The server can also be started from your own V application:

.. code-block:: v

   import vsql

   fn main() {
     mut server := vsql.new_server(
       // Each client opens its own connection to the database. connect can be
       // used instead of db_file to configure the connection, or to open a
       // different database for each database name a client connects with.
       db_file: 'mydb.vsql'

       // A port of 0 uses any free port. host defaults to 127.0.0.1.
       port: 0
     )

     server.listen()!
     println('ready on ' + server.address()!)

     // serve() accepts clients until stop() is called (from another thread).
     server.serve()!
   }

Unlike ``vsql server``, the server doesn't add ``FROM singlerow`` to a ``SELECT``
without a ``FROM`` (which many PostgreSQL clients send, but isn't valid SQL)
unless ``select_without_from`` is set, and doesn't ignore PostgreSQL's ``SET``
of a run-time parameter unless ``ignore_pg_set`` is set. It doesn't accept the
PostgreSQL syntax of catalog queries unless ``rewrite_pg_syntax`` is set, and
doesn't send column names in lower case unless ``lower_case_names`` is set.

See :doc:`install` to get the ``vsql`` command.

.. toctree::
   :maxdepth: 1

   postgresql-clients.rst
