CONNECT
=======

.. contents::

Syntax
------

.. code-block:: text

  CONNECT TO <server> [ AS <name> ] [ USER <user> ]
  CONNECT TO DEFAULT

``CONNECT TO`` opens another database file (or ``':memory:'`` for a new
in-memory database), which becomes the current connection. The connection that
was current becomes dormant, and can be selected again with
:doc:`set-connection`. Connections can only be used in :doc:`cli` (direct SQL),
not with a ``Connection`` in V (use ``vsql.Agent``) or the SQL/CLI routines of
libvsql.

``<server>``, ``<name>`` and ``<user>`` are string literals. The name is an
identifier (so ``'foo'`` and ``'FOO'`` are the same connection), and it's the
server when there's no ``AS``. So, a path like ``'other.vsql'`` needs an
``AS``, otherwise it's ``2E000`` (invalid connection name). A reserved word,
such as ``'SELECT'``, isn't an identifier unless it's quoted (``'"SELECT"'``).
Another connection with the same name is ``08002``, and a file that can't be
opened is ``08001``.
The user must be an identifier (otherwise it's ``28000``), but it's not used.

``DEFAULT`` is the file that ``vsql cli`` was started with. The default
connection is made by the first statement, unless a connection statement
(``CONNECT TO``, ``SET CONNECTION`` or ``DISCONNECT``) is run first. After a
connection statement, there's no implicit connection, so a statement without a
current connection is ``08003``.

Each connection is a different database. A transaction can be across more than
one of them: when it's active on one connection, the first statement on
another connection starts a part of it there (with the same access mode and
isolation level, unless ``SET LOCAL TRANSACTION`` changes them, see
:doc:`set-transaction`). A :doc:`commit` or :doc:`rollback` on any of them ends
every part. A ``COMMIT`` checks the deferred constraints of every part first,
and if any of them fail, every part is rolled back. Committing more than one
database isn't atomic, though: if committing one of them fails (such as because
of a disk error), the ones before it stay committed.

Examples
--------

.. code-block:: text

   $ vsql cli main.vsql
   vsql> CONNECT TO 'archive.vsql' AS 'archive';
   CONNECT (12 ms)

   vsql> SELECT * FROM orders;

   vsql> SET CONNECTION DEFAULT;
   SET CONNECTION (0 ms)

See Also
--------

- :doc:`disconnect`
- :doc:`set-connection`
- :doc:`set-catalog` (for using more than one file in a statement)
