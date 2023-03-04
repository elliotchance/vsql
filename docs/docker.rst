Docker
======

.. contents::

Docker is the easiest way to get up and running (if you have
`Docker installed <https://docs.docker.com/get-docker/>`_.). Pull the latest
stable version with:

.. code-block:: sh

   docker pull elliotchance/vsql:latest

You can also use major (``0``), minor (``0.27``) or patch versions (``0.27.1``).
View all versions on
`hub.docker.com/repository/docker/elliotchance/vsql/tags <https://hub.docker.com/repository/docker/elliotchance/vsql/tags?page=1&ordering=last_updated>`_.

CLI
---

Run the CLI directly:

.. code-block:: sh

   docker run --mount type=bind,source="$(pwd)",target=/db -it elliotchance/vsql:latest cli /db/mydb.vsql

Modify ``source`` to where you want the host directory (it is the current
directory by default). Exit the shell with ``exit``.

**Important:** While it is possible to run vsql without using a mount, this is
not recommended as it will leave the database file on the containers file
system. This will cause the database file will be lost with the container.
Although, sometimes this is the desired behavior:

.. code-block:: sh

   docker run -it elliotchance/vsql:latest cli mydb.vsql

See :doc:`cli`.

Server
------

Start the PostgreSQL-compatible server:

.. code-block:: sh

   docker run --mount type=bind,source="$(pwd)",target=/db -it elliotchance/vsql:latest server /db/mydb.vsql

See :doc:`server`.

Apple M1 Macs
-------------

If you're running on an M1 mac, you might see the following issue warning when
running the container:

.. code-block:: text

   WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested
   GC Warning: getcontext failed: using another register retrieval method...

It doesn't seem like this causes any issues, but if you want to suppress the
message you can set ``DOCKER_DEFAULT_PLATFORM`` before running the container:

.. code-block:: sh

   export DOCKER_DEFAULT_PLATFORM=linux/amd64
