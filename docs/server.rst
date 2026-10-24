Server
======

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

Many PostgreSQL clients send a ``SELECT`` without a ``FROM`` (such as
``SELECT 1``), which isn't valid SQL. ``vsql server`` runs these as if they had
``FROM singlerow``, a table with a single row.

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
unless ``select_without_from`` is set.

See :doc:`install` to get the ``vsql`` command.
