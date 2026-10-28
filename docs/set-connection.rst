SET CONNECTION
==============

.. contents::

Syntax
------

.. code-block:: text

  SET CONNECTION <name>
  SET CONNECTION DEFAULT

``SET CONNECTION`` makes a connection from :doc:`connect` the current
connection. ``<name>`` is a string literal, like ``'archive'``. ``DEFAULT`` is
the file that ``vsql cli`` was started with.

A connection that doesn't exist is ``08003``. If the current connection has an
active transaction, it's ``0A001`` (multiple server transactions).

Examples
--------

.. code-block:: text

   vsql> CONNECT TO 'archive.vsql' AS 'archive';
   vsql> SET CONNECTION DEFAULT;
   vsql> SET CONNECTION 'archive';

See Also
--------

- :doc:`connect`
- :doc:`disconnect`
