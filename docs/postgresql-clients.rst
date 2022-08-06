PostgreSQL Clients
==================

vsql can run as a server that is compatible with PostgreSQL clients. However,
some clients will execute complex or highly PostgreSQL-specific queries during
the connection phase that make them incompatible. This page documents clients
and their compatibility.

Feel free to `open an issue <https://github.com/elliotchance/vsql/issues>`_ or
fork and update this documentation.

Generally speaking, the connection details are:

- **Host:** 127.0.0.1
- **Port:** 3210 (note: this is different from the default PostgreSQL port).
- **Username:** Any value is allowed, including empty.
- **Password:** Any value is allowed, including empty.
- **Database:** Any value is allowed, including empty.

.. contents::

Command Line
------------

✔ psql
^^^^^^

The official PostgreSQL command line client is supported:

.. code-block:: sh

  psql -h 127.0.0.1 -p 3210

GUI Applications
----------------

✔ TablePlus
^^^^^^^^^^^

TablePlus is supported using the following connection options:

- Host/Socket: 127.0.0.1
- Port: 3210
- User: vsql
- Password: Leave empty.
- Database: Leave empty.
- SSL mode: DISABLED

VSCode
------

✖ PostgreSQL (ckolkman.vscode-postgres)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This extension is not supported because it executes several complex queries.
You can view some
`sample queries here <https://gist.github.com/elliotchance/257951d705132134b882258c83297dd6>`_.

✔ SQLTools (mtxr.sqltools)
^^^^^^^^^^^^^^^^^^^^^^^^^^

This is extension is supported. There are some queries executed that are not
compatible, but this doesn't block the connection or execution of custom
queries.

- Connect using: Server and Port
- Server Address: 127.0.0.1
- Port: 3210
- Database: vsql
- Username: vsql
- Use password: Use empty password
- SSL: Disabled
