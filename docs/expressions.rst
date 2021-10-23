Expressions
===========

.. contents::

BETWEEN
-------

.. code-block:: text

  X [ NOT ] BETWEEN [ ASYMMETRIC | SYMMETRIC ] Y AND Z

A ``BETWEEN`` expression returns ``TRUE`` if ``X`` is inclusively between
``Y`` and ``Z``. Or, put another way ``X >= Y AND Z <= Z``.

If ``SYMMETRIC`` is provided, the orders of ``Y`` and ``Z`` are irrelevant. Such
that they will be swapped if ``Y > Z``.

If neither ``ASYMMETRIC`` or ``SYMMETRIC`` is provided then ``ASYMMETRIC`` is
assumed.

*Examples*

.. code-block:: sql

  30 BETWEEN 25 AND 45             -- TRUE
  30 BETWEEN 45 AND 32             -- FALSE
  30 NOT BETWEEN 25 AND 45         -- FALSE
  30 BETWEEN SYMMETRIC 45 AND 32   -- TRUE

IS NULL
-------

.. code-block:: text

  X IS [ NOT ] NULL

Tests if ``X`` is (or is not) ``NULL``.
