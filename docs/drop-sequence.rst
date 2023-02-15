DROP SEQUENCE
=============

.. contents::

Syntax
------

.. code-block:: text

  DROP SEQUENCE <sequence_name>

Delete a sequence.

Examples
--------

The simplest case is to create a sequence with no options. By default a sequence
will start at 1 and increment by 1:

.. code-block:: sql

   CREATE SEQUENCE foo;
   DROP SEQUENCE foo;
   -- msg: CREATE SEQUENCE 1
   -- msg: DROP SEQUENCE 1

See Also
--------

- :doc:`alter-sequence`
- :doc:`create-sequence`
