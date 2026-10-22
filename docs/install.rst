Installing & Updating
=====================

There are lots of ways to install vsql depending on how you want to use it.

.. contents::

Prebuilt Binaries
-----------------

This is the best way to use the ``vsql`` command (see :doc:`cli`) on most
platforms, without installing anything else.

Download the zip for macOS (Apple silicon), Linux (x86-64) or Windows from the
`latest release <https://github.com/elliotchance/vsql/releases/latest>`_ and
unzip it. To update, download the latest release again.

The binaries aren't signed, so macOS may refuse to open one that was downloaded
with a web browser. You can remove the quarantine flag with:

.. code-block:: sh

   xattr -d com.apple.quarantine vsql

Docker
------

If you have `Docker installed <https://docs.docker.com/get-docker/>`_, pull the
latest stable version with:

.. code-block:: sh

   docker pull elliotchance/vsql:latest

See :doc:`docker` for more information.

V Package Manager
-----------------

This is the best method if you intend to build V applications using it as a
library (see :doc:`v-client-library`):

.. code-block:: sh

   v install elliotchance.vsql

Run the same command to update it. vsql is built and tested with the latest V
every day, and older versions of V may not be able to compile it, so update V
first with ``v up``.

Compiling From Source
---------------------

This is the best choice if you want to modify vsql or contribute to the project
(see :doc:`contributing`):

.. code-block:: sh

   git clone https://github.com/elliotchance/vsql.git
   cd vsql
   make bin/vsql
