DISCONNECT
==========

.. contents::

Syntax
------

.. code-block:: text

  DISCONNECT <name>
  DISCONNECT DEFAULT
  DISCONNECT CURRENT
  DISCONNECT ALL

``DISCONNECT`` closes a connection from :doc:`connect`, the default connection,
the current connection, or all of them. If the current connection is closed,
there is no current connection until :doc:`connect` or :doc:`set-connection`.

A connection that doesn't exist is ``08003``. A connection with an active
transaction can't be closed (``25001``), so use :doc:`commit` or
:doc:`rollback` first.

Examples
--------

.. code-block:: text

   vsql> CONNECT TO 'archive.vsql' AS 'archive';
   vsql> DISCONNECT CURRENT;
   vsql> VALUES 1;
   Error 08003: connection does not exist: there is no current SQL-connection

See Also
--------

- :doc:`connect`
- :doc:`set-connection`
