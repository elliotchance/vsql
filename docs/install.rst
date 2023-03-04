Installing & Updating
=====================

There are lots of ways to install vsql depending on how you want to use it.

.. contents::

Docker
------

Docker is the easiest way to get up and running (if you have
`Docker installed <https://docs.docker.com/get-docker/>`_.). Pull the latest
stable version with:

.. code-block:: sh

   docker pull elliotchance/vsql:latest

See :doc:`docker` for more information.

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
