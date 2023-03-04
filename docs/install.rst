Installing & Updating
=====================

There are lots of ways to install vsql depending on how you want to use it.

Docker
------

Docker is the easiest way to get up and running (if you have
`Docker installed <https://docs.docker.com/get-docker/>`_.). Pull the latest
stable version with:

.. code-block:: sh

   docker pull elliotchance/vsql:latest

You can also use major (``0``), minor (``0.27``) or patch versions (``0.27.1``).
View all versions on
`hub.docker.com/repository/docker/elliotchance/vsql/tags <https://hub.docker.com/repository/docker/elliotchance/vsql/tags?page=1&ordering=last_updated>`_.

Run the CLI directly (see :doc:`cli`):

.. code-block:: sh

   docker run -it elliotchance/vsql:latest cli mydb.vsql

Or, start the PostgreSQL-compatible server (see :doc:`server`):

.. code-block:: sh

   docker run -it elliotchance/vsql:latest server mydb.vsql

Prebuilt Binaries
-----------------

This is the best way to use vsql on most platforms without any dependencies.

Prebuilt binaries for macOS, Windows and Linux are available on the
`GitHub Releases Page <https://github.com/elliotchance/vsql/releases>`_.

V Package Manager
-----------------

This is the best method if you intend to build V applications using it as a
library. See `v-client-library`.

.. code-block:: sh

   v install elliotchance.vsql

Compiling From Source
---------------------

This is the best choice if you want to modify vsql source or contribute to the
project. See :doc:`contributing`:

.. code-block:: sh

   git clone https://github.com/elliotchance/vsql.git
   cd vsql
   make bin/vsql
