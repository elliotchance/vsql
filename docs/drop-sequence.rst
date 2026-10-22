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

.. code-block:: sql

   CREATE SEQUENCE foo;
   DROP SEQUENCE foo;
   -- msg: CREATE SEQUENCE 1
   -- msg: DROP SEQUENCE 1

See Also
--------

- :doc:`alter-sequence`
- :doc:`create-sequence`
