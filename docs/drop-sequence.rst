DROP SEQUENCE
=============

.. contents::

Syntax
------

.. code-block:: text

  DROP SEQUENCE [ IF EXISTS ] <sequence_name> [ CASCADE | RESTRICT ]

Delete a sequence.

``RESTRICT`` returns an error (and takes no action) if any other object depends
on the sequence. ``CASCADE`` also drops the objects that depend on the sequence.
Nothing can depend on a sequence yet (such as a column default), so they are
currently the same.

The SQL standard requires one of ``CASCADE`` or ``RESTRICT``, but vsql also
allows neither, which is the same as ``RESTRICT``.

With ``IF EXISTS``, a sequence that doesn't exist isn't an error. Nothing changes,
and the result is ``DROP SEQUENCE 0``. That includes a sequence in a schema that
doesn't exist, but a catalog that doesn't exist is still an error. If the sequence
exists, it's the same as ``DROP SEQUENCE``.

``IF EXISTS`` is a vsql extension, not standard SQL. It's flagged as ``V107-02``
(see :doc:`sql-flagging`).

Examples
--------

.. code-block:: sql

   CREATE SEQUENCE foo;
   DROP SEQUENCE foo;
   -- msg: CREATE SEQUENCE 1
   -- msg: DROP SEQUENCE 1

See Also
--------

- :doc:`alter-sequence`
- :doc:`create-sequence`
