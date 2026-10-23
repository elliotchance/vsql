DROP SEQUENCE
=============

.. contents::

Syntax
------

.. code-block:: text

  DROP SEQUENCE <sequence_name> [ CASCADE | RESTRICT ]

Delete a sequence.

``RESTRICT`` returns an error (and takes no action) if any other object depends
on the sequence. ``CASCADE`` also drops the objects that depend on the sequence.
Nothing can depend on a sequence yet (such as a column default), so they are
currently the same.

The SQL standard requires one of ``CASCADE`` or ``RESTRICT``, but vsql also
allows neither, which is the same as ``RESTRICT``.

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
