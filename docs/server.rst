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

Binary releases can be downloaded from the
`Releases <https://github.com/elliotchance/vsql/releases>`_ page (under Assets).

These binary releases do not require V to be installed. Or, you can compile from
source with:

.. code-block:: sh

   make bin/vsql       # macOS and linux
   make bin/vsql.exe   # windows
