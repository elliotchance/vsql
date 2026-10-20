Server
======

vsql can be run as a server and any PostgreSQL-compatible driver can access it.
This is ideal if you want to use a more familar or feature rich database client.

See the :doc:`list of supported clients here<postgresql-clients>`.

Now run it with (if the file does not exist it will be created):

.. code-block:: text

   $ vsql server mydb.vsql
   ready on 127.0.0.1:3210

vsql will ignore any authentication values (such as user, password, database,
etc). Simply connect using ``127.0.0.1:3210``.

Any number of clients can be connected at the same time. Each client has its own
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

       // A port of 0 uses any free port.
       port: 0
     )

     server.listen()!
     port := server.port()!
     println('ready on 127.0.0.1:' + port.str())

     // serve() accepts clients until stop() is called (from another thread).
     server.serve()!
   }

Unlike ``vsql server``, the server doesn't add ``FROM singlerow`` to a ``SELECT``
without a ``FROM`` (which many PostgreSQL clients send, but isn't valid SQL)
unless ``select_without_from`` is set.

Binary releases can be downloaded from the
`Releases <https://github.com/elliotchance/vsql/releases>`_ page (under Assets).

These binary releases do not require V to be installed. Or, you can compile from
source with:

.. code-block:: sh

   make bin/vsql       # macOS and linux
   make bin/vsql.exe   # windows
