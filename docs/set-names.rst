SET NAMES
=========

.. contents::

Syntax
------

.. code-block:: text

  SET NAMES <expr>

``SET NAMES`` sets the default character set of the connection. vsql only has one
character set, so the only name is ``UTF8``, and this doesn't change anything.

The value is a character string (otherwise it's ``42804``) that contains the name
as an identifier, without the spaces around it, so ``'utf8'`` and ``'"UTF8"'`` are
also ``UTF8``. Anything else, such as ``'LATIN1'`` or ``'UTF-8'``, is ``2C000``.

Examples
--------

.. code-block:: sql

  SET NAMES 'UTF8';
  -- msg: SET NAMES

  SET NAMES 'LATIN1';
  -- error 2C000: invalid character set name: LATIN1
