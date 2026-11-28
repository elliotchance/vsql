Functions by Category
=====================

Each function is in one category. The code block below each function's name
lists each combination of argument types it accepts and the type of the
result.

Unless the function says otherwise:

- The result is ``NULL`` if any argument is ``NULL``. A bare ``NULL`` can't be an
  argument because it has no type (``ABS(NULL)`` is a syntax error), so use a
  ``CAST``, such as ``ABS(CAST(NULL AS INTEGER))``.

- A function called with an argument of the wrong kind, such as
  ``UPPER(123)``, returns a ``42883`` error (function does not exist). Numbers
  and strings are not converted to each other.

Functions that aren't listed here can be added with :doc:`custom-functions`.

Each function also has a **Compatibility** section:

- **SQL standard** is the feature of ISO/IEC 9075-2:2023 (SQL:2023) that the
  function belongs to. Core SQL is the part of the standard that every
  conforming database has to support, the others are optional features. See
  :doc:`sql-compliance-9075-2` for all of the features, and :doc:`sql-flagging` to
  find SQL that isn't standard.

- **Other databases** is how to get the same result in PostgreSQL, MySQL,
  SQLite, SQL Server and Oracle, with the same or a different name. The
  mathematical functions of SQLite (other than ``ABS``) need
  ``SQLITE_ENABLE_MATH_FUNCTIONS``, which is on by default since SQLite 3.35.

The functions are in these categories:

.. toctree::
   :maxdepth: 1

   functions-aggregate.rst
   functions-arithmetic.rst
   functions-build.rst
   functions-conditional.rst
   functions-date-and-time.rst
   functions-error-and-gamma.rst
   functions-exponent-and-logarithm.rst
   functions-number-base.rst
   functions-random.rst
   functions-rounding.rst
   functions-session.rst
   functions-statistical.rst
   functions-string.rst
   functions-trigonometric.rst
   functions-uuid.rst
