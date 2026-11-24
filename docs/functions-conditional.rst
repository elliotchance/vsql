Conditional Functions
=====================

.. contents::
   :local:
   :depth: 1

Conditional functions choose between values. Unlike other functions, their
result isn't always ``NULL`` when an argument is ``NULL``. See also ``CASE`` in
:doc:`expressions`.

COALESCE
^^^^^^^^

.. code-block:: sql

   COALESCE(ANY, ANY, ...) ANY

``COALESCE`` returns the first value that is not ``NULL``. If all values are
``NULL`` then ``NULL`` is also returned.

It needs at least two values and they must have compatible types (all character
strings, all numbers, all ``BOOLEAN`` or the same kind of date or time),
otherwise it's a ``42804`` error. The result has a type that can hold any of
them, so ``COALESCE(1, 2.5)`` is a ``NUMERIC``.

The values are checked in order, and the values after the first one that is not
``NULL`` aren't evaluated. So ``COALESCE(1, 1 / 0)`` is 1, not an error.

``COALESCE(x, y)`` is the same as:

.. code-block:: sql

  CASE WHEN x IS NOT NULL THEN x ELSE y END

**Examples**

.. code-block:: sql

  VALUES COALESCE(1, 2);
  -- COL1: 1

  VALUES COALESCE(CAST(NULL AS INTEGER), 2);
  -- COL1: 2

  VALUES COALESCE(1, 2.5);
  -- COL1: 1.0

  VALUES COALESCE(1, 'a');
  -- error 42804: data type mismatch in argument 2 of COALESCE: expected INTEGER but got CHARACTER(1)

**Compatibility**

- **SQL standard:** Core SQL (F261-04).
- **Other databases:** ``COALESCE`` in all of them. There are also two
  argument versions: ``IFNULL`` (MySQL, SQLite), ``ISNULL`` (SQL Server) and
  ``NVL`` (Oracle).

GREATEST
^^^^^^^^

.. code-block:: sql

   GREATEST(ANY, ANY, ...) ANY

``GREATEST`` returns the greatest of the values. If any of the values is
``NULL`` then the result is ``NULL``.

It needs at least two values and they must be comparable with each other,
otherwise it's a ``42883`` error. Like ``COALESCE``, the result has a type that
can hold any of them, so ``GREATEST(1, 2.5)`` is a ``NUMERIC``.

Strings that are only different in their trailing spaces are equal, such as
``'a'`` and ``'a '``, so either one could be the result. That's why
``GREATEST`` of strings (or of times with a time zone) can't be used in a
``CHECK`` constraint or a generated column.

See also `LEAST`_.

**Examples**

.. code-block:: sql

  VALUES GREATEST(1, 3, 2);
  -- COL1: 3

  VALUES GREATEST(1, CAST(NULL AS INT));
  -- COL1: NULL

**Compatibility**

- **SQL standard:** Optional feature T054.
- **Other databases:** ``GREATEST`` in MySQL, PostgreSQL and SQL Server, but
  PostgreSQL ignores ``NULL`` values instead. SQLite uses ``MAX`` with more
  than one argument.

IF
^^

.. code-block:: sql

   IF(BOOLEAN, ANY, ANY) ANY

``IF(condition, then_value, else_value)`` returns ``then_value`` if the
condition is ``TRUE``, otherwise ``else_value``. A condition that is ``FALSE``
or ``UNKNOWN`` (``NULL``) returns ``else_value``.

The condition must be a ``BOOLEAN`` (any search condition, such as
``x > 0 AND y IS NOT NULL``), otherwise it's a ``42804`` error. The two values
must have compatible types, and the result has a type that can hold either of
them, like ``COALESCE``. It needs exactly three arguments.

Only the value that's chosen is evaluated, so ``IF(x = 0, 0, 1 / x)`` doesn't
divide by zero.

``IF(c, x, y)`` is the same as:

.. code-block:: sql

  CASE WHEN c THEN x ELSE y END

``IF`` is a vsql extension flagged by ``V401-01`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES IF(1 < 2, 'yes', 'no');
  -- COL1: yes

  VALUES IF(CAST(NULL AS BOOLEAN), 1, 0);
  -- COL1: 0

  VALUES IF(TRUE, 1, 2.5);
  -- COL1: 1.0

**Compatibility**

- **SQL standard:** not standard, use ``CASE``.
- **Other databases:** ``IF`` in MySQL, ``IIF`` in SQL Server and SQLite (where
  ``IF`` is another name for it). PostgreSQL and Oracle use ``CASE``.

LEAST
^^^^^

.. code-block:: sql

   LEAST(ANY, ANY, ...) ANY

``LEAST`` returns the least of the values. If any of the values is ``NULL``
then the result is ``NULL``.

It needs at least two values and they must be comparable with each other,
otherwise it's a ``42883`` error. Like ``COALESCE``, the result has a type that
can hold any of them, so ``LEAST(1, 2.5)`` is a ``NUMERIC``.

Strings that are only different in their trailing spaces are equal, such as
``'a'`` and ``'a '``, so either one could be the result. That's why ``LEAST``
of strings (or of times with a time zone) can't be used in a ``CHECK``
constraint or a generated column.

See also `GREATEST`_.

**Examples**

.. code-block:: sql

  VALUES LEAST('b', 'a', 'c');
  -- COL1: a

  VALUES LEAST(1, CAST(NULL AS INT));
  -- COL1: NULL

**Compatibility**

- **SQL standard:** Optional feature T054.
- **Other databases:** ``LEAST`` in MySQL, PostgreSQL and SQL Server, but
  PostgreSQL ignores ``NULL`` values instead. SQLite uses ``MIN`` with more
  than one argument.

NULLIF
^^^^^^

.. code-block:: sql

   NULLIF(ANY, ANY) ANY

``NULLIF(VALUE1, VALUE2)`` returns ``NULL`` if ``VALUE1`` and ``VALUE2`` are
equal. Otherwise
``VALUE1`` is returned. The result has the type of ``VALUE1``.

The values are compared with ``=``, so ``1`` and ``1.0`` are equal, and so are
``'a'`` and ``'a '``. They must have compatible types, otherwise it's a
``42804`` error. If either value is ``NULL`` they aren't equal, so ``VALUE1``
is returned.

``NULLIF`` is useful to avoid dividing by zero, ``x / NULLIF(y, 0)`` is
``NULL`` instead of an error when ``y`` is 0.

``NULLIF(x, y)`` is the same as:

.. code-block:: sql

  CASE WHEN x = y THEN NULL ELSE x END

**Examples**

.. code-block:: sql

  VALUES NULLIF(123, 123);
  -- COL1: NULL

  VALUES NULLIF(123, 456);
  -- COL1: 123

  VALUES NULLIF(1, 1.0);
  -- COL1: NULL

**Compatibility**

- **SQL standard:** Core SQL (F261-03).
- **Other databases:** ``NULLIF`` in all of them.
