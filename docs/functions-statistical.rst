Statistical Functions
=====================

.. contents::
   :local:
   :depth: 1

Statistical functions are aggregate functions (see
:doc:`functions-aggregate`) that describe
the spread of a set of numbers, or the relationship between two sets of
numbers. They accept any number, which is converted to a ``DOUBLE PRECISION``,
and they return a ``DOUBLE PRECISION`` (except ``REGR_COUNT``). They can't be
used with ``DISTINCT`` or ``ALL`` (a ``42601`` error).

The functions with two arguments, ``FUNCTION(Y, X)``, treat each row as a
point, where ``Y`` is the dependent variable (the vertical axis) and ``X`` is
the independent variable (the horizontal axis). Note that ``Y`` is first. A
row is ignored if either value is ``NULL``, with a ``01003`` warning. The
regression functions describe the line that fits the points best (the
least-squares line), ``Y = REGR_SLOPE(Y, X) * X + REGR_INTERCEPT(Y, X)``.

``NULL`` is returned when there are no rows, and for the functions that can't
be calculated from the rows (such as the sample variance of one row). A result
that is too large or too small to be a ``DOUBLE PRECISION`` is a ``22003``
error, except for ``CORR``, ``REGR_R2``, ``REGR_SLOPE`` and
``REGR_INTERCEPT``, which return ``NULL`` instead.

The results are calculated so that they're still accurate when the values are
very large or very close together, which can make them slightly different
(in the last digits) from the formulas below.

The examples use this table:

.. code-block:: sql

  CREATE TABLE points (x FLOAT, y FLOAT);
  INSERT INTO points (x, y) VALUES
    (1e0, 1e0), (2e0, 3e0), (3e0, 2e0), (4e0, 5e0), (5e0, NULL);

CORR
^^^^

.. code-block:: sql

   CORR(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``CORR(Y, X)`` is the correlation coefficient (Pearson's), between -1 and 1. It
is 1 when the points are on a line that goes up, -1 when they're on a line that
goes down, and close to 0 when ``Y`` doesn't depend on ``X``. It's
``REGR_SXY / SQRT(REGR_SXX * REGR_SYY)``.

The result is ``NULL`` if there are no rows, or if every ``X`` (or every ``Y``)
is the same.

**Examples**

.. code-block:: sql

  SELECT CORR(y, x), CORR(-y, x) FROM points;
  -- COL1: 0.83152184062e0 COL2: -0.83152184062e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions). The standard defines ``CORR`` as the square root of ``REGR_R2``, which is never negative. vsql returns the sign as well, like the other databases.
- **Other databases:** PostgreSQL and Oracle: ``CORR``. MySQL, SQLite and SQL Server don't have it.

COVAR_POP
^^^^^^^^^

.. code-block:: sql

   COVAR_POP(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``COVAR_POP(Y, X)`` is the population covariance, ``REGR_SXY / N`` where ``N``
is the number of rows. It's positive when ``Y`` tends to be larger when ``X`` is
larger, and negative when ``Y`` tends to be smaller.

**Examples**

.. code-block:: sql

  SELECT COVAR_POP(y, x) FROM points;
  -- COL1: 1.375e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``COVAR_POP``. MySQL, SQLite and SQL Server don't have it.

COVAR_SAMP
^^^^^^^^^^

.. code-block:: sql

   COVAR_SAMP(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``COVAR_SAMP(Y, X)`` is the sample covariance, ``REGR_SXY / (N - 1)`` where
``N`` is the number of rows. The result is ``NULL`` if there are less than two
rows.

**Examples**

.. code-block:: sql

  SELECT COVAR_SAMP(y, x) FROM points;
  -- COL1: 1.833333333333e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``COVAR_SAMP``. MySQL, SQLite and SQL Server don't have it.

REGR_AVGX
^^^^^^^^^

.. code-block:: sql

   REGR_AVGX(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_AVGX(Y, X)`` is the average of ``X``. Unlike ``AVG(X)``, it ignores the
rows where ``Y`` is ``NULL``.

**Examples**

.. code-block:: sql

  SELECT REGR_AVGX(y, x), AVG(x) FROM points;
  -- COL1: 2.5e0 COL2: 3e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_AVGX``. MySQL, SQLite and SQL Server don't have it.

REGR_AVGY
^^^^^^^^^

.. code-block:: sql

   REGR_AVGY(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_AVGY(Y, X)`` is the average of ``Y``. Unlike ``AVG(Y)``, it ignores the
rows where ``X`` is ``NULL``.

**Examples**

.. code-block:: sql

  SELECT REGR_AVGY(y, x) FROM points;
  -- COL1: 2.75e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_AVGY``. MySQL, SQLite and SQL Server don't have it.

REGR_COUNT
^^^^^^^^^^

.. code-block:: sql

   REGR_COUNT(DOUBLE PRECISION, DOUBLE PRECISION) INTEGER

``REGR_COUNT(Y, X)`` is the number of rows where neither ``Y`` nor ``X`` is
``NULL``. It's 0 when there are no rows.

**Examples**

.. code-block:: sql

  SELECT COUNT(*), REGR_COUNT(y, x) FROM points;
  -- COL1: 5 COL2: 4

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_COUNT``. MySQL, SQLite and SQL Server don't have it. PostgreSQL returns a ``BIGINT``.

REGR_INTERCEPT
^^^^^^^^^^^^^^

.. code-block:: sql

   REGR_INTERCEPT(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_INTERCEPT(Y, X)`` is the value of ``Y`` where the line that fits the
points crosses ``X = 0``, ``REGR_AVGY - REGR_SLOPE * REGR_AVGX``.

The result is ``NULL`` if there are no rows, or if every ``X`` is the same
(because the line would be vertical).

**Examples**

.. code-block:: sql

  SELECT REGR_INTERCEPT(y, x) FROM points;
  -- COL1: 0e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_INTERCEPT``. MySQL, SQLite and SQL Server don't have it.

REGR_R2
^^^^^^^

.. code-block:: sql

   REGR_R2(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_R2(Y, X)`` is the coefficient of determination, between 0 and 1. It's
how well the line fits the points, from 0 (not at all) to 1 (every point is on
the line). It's the square of ``CORR``.

The result is ``NULL`` if there are no rows, or if every ``X`` is the same.
Otherwise, it's 1 if every ``Y`` is the same (because the line is horizontal).

**Examples**

.. code-block:: sql

  SELECT REGR_R2(y, x) FROM points;
  -- COL1: 0.691428571429e0

  SELECT REGR_R2(2, x) FROM points;
  -- COL1: 1e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_R2``. MySQL, SQLite and SQL Server don't have it.

REGR_SLOPE
^^^^^^^^^^

.. code-block:: sql

   REGR_SLOPE(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SLOPE(Y, X)`` is the slope of the line that fits the points, which is
how much ``Y`` increases for each 1 that ``X`` increases, ``REGR_SXY /
REGR_SXX``.

The result is ``NULL`` if there are no rows, or if every ``X`` is the same
(because the line would be vertical).

**Examples**

.. code-block:: sql

  SELECT REGR_SLOPE(y, x) FROM points;
  -- COL1: 1.1e0

  SELECT REGR_SLOPE(y, 2) FROM points;
  -- COL1: NULL

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SLOPE``. MySQL, SQLite and SQL Server don't have it.

REGR_SXX
^^^^^^^^

.. code-block:: sql

   REGR_SXX(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SXX(Y, X)`` is the sum of the squares of the differences between each
``X`` and the average of ``X``, ``SUM(X * X) - SUM(X) * SUM(X) / N`` where ``N``
is the number of rows. It's 0 if every ``X`` is the same.

**Examples**

.. code-block:: sql

  SELECT REGR_SXX(y, x) FROM points;
  -- COL1: 5e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SXX``. MySQL, SQLite and SQL Server don't have it.

REGR_SXY
^^^^^^^^

.. code-block:: sql

   REGR_SXY(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SXY(Y, X)`` is the sum of the products of the differences between each
``X`` and the average of ``X``, and each ``Y`` and the average of ``Y``,
``SUM(X * Y) - SUM(X) * SUM(Y) / N`` where ``N`` is the number of rows.

**Examples**

.. code-block:: sql

  SELECT REGR_SXY(y, x) FROM points;
  -- COL1: 5.5e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SXY``. MySQL, SQLite and SQL Server don't have it.

REGR_SYY
^^^^^^^^

.. code-block:: sql

   REGR_SYY(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SYY(Y, X)`` is the sum of the squares of the differences between each
``Y`` and the average of ``Y``, ``SUM(Y * Y) - SUM(Y) * SUM(Y) / N`` where ``N``
is the number of rows. It's 0 if every ``Y`` is the same.

**Examples**

.. code-block:: sql

  SELECT REGR_SYY(y, x) FROM points;
  -- COL1: 8.75e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SYY``. MySQL, SQLite and SQL Server don't have it.

STDDEV_POP
^^^^^^^^^^

.. code-block:: sql

   STDDEV_POP(DOUBLE PRECISION) DOUBLE PRECISION

``STDDEV_POP(X)`` is the population standard deviation, the square root of
``VAR_POP``.

**Examples**

.. code-block:: sql

  SELECT STDDEV_POP(y) FROM points;
  -- COL1: 1.479019945775e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL, MySQL (also ``STD`` and ``STDDEV``) and Oracle:
    ``STDDEV_POP``.
  - SQL Server: ``STDEVP``.
  - SQLite doesn't have it.

STDDEV_SAMP
^^^^^^^^^^^

.. code-block:: sql

   STDDEV_SAMP(DOUBLE PRECISION) DOUBLE PRECISION

``STDDEV_SAMP(X)`` is the sample standard deviation, the square root of
``VAR_SAMP``. The result is ``NULL`` if there are less than two values.

**Examples**

.. code-block:: sql

  SELECT STDDEV_SAMP(y) FROM points;
  -- COL1: 1.70782512766e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL (also ``STDDEV``), MySQL and Oracle: ``STDDEV_SAMP``. In MySQL,
    ``STDDEV`` is ``STDDEV_POP``. In Oracle, ``STDDEV`` is 0 for one value.
  - SQL Server: ``STDEV``.
  - SQLite doesn't have it.

VAR_POP
^^^^^^^

.. code-block:: sql

   VAR_POP(DOUBLE PRECISION) DOUBLE PRECISION

``VAR_POP(X)`` is the population variance, the average of the squares of
the differences between each value and the average,
``(SUM(X * X) - SUM(X) * SUM(X) / N) / N`` where ``N`` is the number of values.

**Examples**

.. code-block:: sql

  SELECT VAR_POP(y) FROM points;
  -- COL1: 2.1875e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL, MySQL (also ``VARIANCE``) and Oracle: ``VAR_POP``.
  - SQL Server: ``VARP``.
  - SQLite doesn't have it.

VAR_SAMP
^^^^^^^^

.. code-block:: sql

   VAR_SAMP(DOUBLE PRECISION) DOUBLE PRECISION

``VAR_SAMP(X)`` is the sample variance, ``(SUM(X * X) - SUM(X) * SUM(X) /
N) / (N - 1)`` where ``N`` is the number of values. The result is ``NULL`` if
there are less than two values.

**Examples**

.. code-block:: sql

  SELECT VAR_SAMP(y) FROM points;
  -- COL1: 2.916666666667e0

  SELECT VAR_SAMP(y) FROM points WHERE x = 1;
  -- COL1: NULL

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL (also ``VARIANCE``), MySQL and Oracle: ``VAR_SAMP``. In MySQL,
    ``VARIANCE`` is ``VAR_POP``. In Oracle, ``VARIANCE`` is 0 for one value.
  - SQL Server: ``VAR``.
  - SQLite doesn't have it.
