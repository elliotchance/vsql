Spreadsheet Functions
=====================

.. contents::
   :local:
   :depth: 1

How to write the formulas you know from Microsoft Excel and Google Sheets in
vsql. Every function of both is here, in the same categories as Excel, and
each one can be linked to by its name, such as
``compatibility-spreadsheet.html#vlookup``. Functions that have no equivalent in
vsql are listed too, so you can tell that they haven't been missed.

Formulas and Queries
--------------------

A formula on literal values becomes a ``VALUES``, so ``=ROUND(2.345, 2)`` is
``VALUES ROUND(2.345, 2);``. A range becomes a column of a table, so
``=SUM(D2:D5)`` is ``SELECT SUM(qty) FROM products;``, and a condition such as
the one in ``SUMIF`` becomes a ``WHERE`` or a ``FILTER (WHERE ...)``.

Each function shows the formula with the names of its arguments, and below
it the same statement in vsql with each argument as a comment where its value
goes. An example follows on the example tables, with its result:

.. code-block:: sql

  -- =MID(text, start_num, num_chars)
  VALUES SUBSTRING(/*text*/ FROM /*start_num*/ FOR /*num_chars*/);
  -- =MID("Apple", 2, 3)
  VALUES SUBSTRING('Apple' FROM 2 FOR 3);
  -- COL1: ppl

When an optional argument changes the statement, each form has its own
statement and example. A comment that isn't the name of an argument says what
goes there instead, such as ``/*table*/`` for the table that a range is a
column of, or ``/*key*/`` for the column that puts the rows in the order of
the sheet.

There are a few other differences to watch for:

- Text is in single quotes (``'Apple'``). Double quotes are for names of
  tables and columns.
- Dividing two integers gives an integer, so ``10 / 4`` is 2, and a decimal
  keeps the decimal places of its operands, so ``1 / 3.0`` is 0.3. Write
  ``10 / 4e0`` to divide as a spreadsheet does, which gives ``2.5e0``.
- An average of an integer or decimal column has the same decimal places as
  the column, so it's rounded down. Use ``AVG(CAST(qty AS DOUBLE PRECISION))``
  for the exact average.
- An empty cell is ``NULL``. Most functions return ``NULL`` when an argument is
  ``NULL``, and aggregates such as ``SUM`` and ``AVG`` skip it, like a
  spreadsheet skips empty cells.
- There are no error values such as ``#N/A`` or ``#DIV/0!``. A statement that
  fails returns an error instead (see :doc:`sqlstate`).

Example Tables
--------------

The examples use these three tables. Each one is a range of a sheet with a
header row, so ``products`` is ``A1:D5``, with ``sku`` in column A, ``name``
in B, ``price`` in C and ``qty`` in D. ``points`` and ``flows`` are both
``A1:B5``.

.. code-block:: sql

  CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
  INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);

  CREATE TABLE points (x DOUBLE PRECISION, y DOUBLE PRECISION);
  INSERT INTO points VALUES (1e0, 2e0), (2e0, 4.1e0), (3e0, 5.9e0), (4e0, 8.2e0);

  CREATE TABLE flows (n INTEGER, amount DOUBLE PRECISION);
  INSERT INTO flows VALUES (1, -100e0), (2, 30e0), (3, 40e0), (4, 50e0);

Add-in and Automation
---------------------

CALL
^^^^

.. code-block:: text

  =CALL(register_id, [argument1], ...)

Calls a procedure in a code library or resource. Only in Excel.

No equivalent.

COPILOT
^^^^^^^

.. code-block:: text

  =COPILOT(prompt_part1, [context1], [prompt_part2], [context2], ...)

Asks an AI model a question about the given prompt and data. Only in Excel.

No equivalent.

EUROCONVERT
^^^^^^^^^^^

Converts an amount between the euro and a former euro-zone currency at the fixed rate. Only in Excel.

.. code-block:: sql

  -- =EUROCONVERT(number, source, "EUR")
  VALUES ROUND(/*number*/ / /*euro rate of source*/, 2);
  -- =EUROCONVERT(1.2, "DEM", "EUR")
  VALUES ROUND(1.2 / 1.95583, 2);
  -- COL1: 0.61

The fixed rate (1.95583 Deutsche Mark to the euro) has to be written in.

PY
^^

.. code-block:: text

  =PY(python_code, return_type)

Runs Python code in the cell and returns its result. Only in Excel.

No equivalent.

REGISTER.ID
^^^^^^^^^^^

.. code-block:: text

  =REGISTER.ID(module_text, procedure, [type_text])

Returns the ID of a registered code library procedure. Only in Excel.

No equivalent.

Compatibility
-------------

BETADIST
^^^^^^^^

.. code-block:: text

  =BETADIST(x, alpha, beta, [a], [b])

Returns the cumulative beta distribution. Only in Excel.

No equivalent.

BETAINV
^^^^^^^

.. code-block:: text

  =BETAINV(probability, alpha, beta, [a], [b])

Returns the value at which the cumulative beta distribution reaches a probability. Only in Excel.

No equivalent.

BINOMDIST
^^^^^^^^^

Returns the binomial probability of a number of successes in a number of trials.

.. code-block:: sql

  -- =BINOMDIST(number_s, trials, probability_s, FALSE)
  VALUES FACTORIAL(/*trials*/) / (FACTORIAL(/*number_s*/) * FACTORIAL(/*trials*/ - /*number_s*/))
    * POWER(/*probability_s*/, /*number_s*/) * POWER(1 - /*probability_s*/, /*trials*/ - /*number_s*/);
  -- =BINOMDIST(2, 5, 0.5, FALSE)
  VALUES FACTORIAL(5) / (FACTORIAL(2) * FACTORIAL(5 - 2))
    * POWER(0.5e0, 2) * POWER(1 - 0.5e0, 5 - 2);
  -- COL1: 0.3125e0

The binomial coefficient COMBIN(trials, number_s) is written with FACTORIAL. For cumulative TRUE, add up the terms for 0 to number_s.

CEILING
^^^^^^^

Rounds a number up to the nearest multiple of another number.

.. code-block:: sql

  -- =CEILING(number, significance)
  VALUES CEIL(/*number*/ / /*significance*/) * /*significance*/;
  -- =CEILING(17, 5)
  VALUES CEIL(17 / 5.0) * 5;
  -- COL1: 20

CHIDIST
^^^^^^^

.. code-block:: text

  =CHIDIST(x, deg_freedom)

Returns the right-tailed probability of the chi-squared distribution.

No equivalent.

CHIINV
^^^^^^

.. code-block:: text

  =CHIINV(probability, deg_freedom)

Returns the inverse of the right-tailed chi-squared distribution.

No equivalent.

CHITEST
^^^^^^^

.. code-block:: text

  =CHITEST(actual_range, expected_range)

Returns the p-value of a chi-squared test of independence.

No equivalent.

CONFIDENCE
^^^^^^^^^^

.. code-block:: text

  =CONFIDENCE(alpha, standard_dev, size)

Returns the half-width of a confidence interval for a mean, using the normal distribution.

No equivalent.

COVAR
^^^^^

Returns the population covariance of two sets of values.

.. code-block:: sql

  -- =COVAR(array1, array2)
  SELECT COVAR_POP(/*array1*/, /*array2*/) FROM /*table*/;
  -- =COVAR(B2:B5, A2:A5)
  SELECT COVAR_POP(y, x) FROM points;
  -- COL1: 2.55e0

CRITBINOM
^^^^^^^^^

.. code-block:: text

  =CRITBINOM(trials, probability_s, alpha)

Returns the smallest number of successes whose cumulative binomial probability reaches a criterion.

No equivalent.

EXPONDIST
^^^^^^^^^

Returns the exponential distribution.

.. code-block:: sql

  -- =EXPONDIST(x, lambda, TRUE)
  VALUES 1 - EXP(-/*lambda*/ * /*x*/);
  -- =EXPONDIST(0.5, 2, TRUE)
  VALUES 1 - EXP(-2 * 0.5e0);
  -- COL1: 0.632120558829e0

  -- =EXPONDIST(x, lambda, FALSE)
  VALUES /*lambda*/ * EXP(-/*lambda*/ * /*x*/);
  -- =EXPONDIST(0.5, 2, FALSE)
  VALUES 2 * EXP(-2 * 0.5e0);
  -- COL1: 0.735758882343e0

For cumulative FALSE, use 2 * EXP(-2 * 0.5e0).

FDIST
^^^^^

.. code-block:: text

  =FDIST(x, deg_freedom1, deg_freedom2)

Returns the right-tailed F probability distribution.

No equivalent.

FINV
^^^^

.. code-block:: text

  =FINV(probability, deg_freedom1, deg_freedom2)

Returns the inverse of the right-tailed F probability distribution.

No equivalent.

FLOOR
^^^^^

Rounds a number down to the nearest multiple of another number.

.. code-block:: sql

  -- =FLOOR(number, significance)
  VALUES FLOOR(/*number*/ / /*significance*/) * /*significance*/;
  -- =FLOOR(17, 5)
  VALUES FLOOR(17 / 5.0) * 5;
  -- COL1: 15

FORECAST
^^^^^^^^

Predicts a value on the straight line fitted to known values.

.. code-block:: sql

  -- =FORECAST(x, known_ys, known_xs)
  SELECT REGR_INTERCEPT(/*known_ys*/, /*known_xs*/) + REGR_SLOPE(/*known_ys*/, /*known_xs*/) * /*x*/ FROM /*table*/;
  -- =FORECAST(5, B2:B5, A2:A5)
  SELECT REGR_INTERCEPT(y, x) + REGR_SLOPE(y, x) * 5 FROM points;
  -- COL1: 10.15e0

FTEST
^^^^^

.. code-block:: text

  =FTEST(array1, array2)

Returns the p-value of an F-test on the variances of two sets of values.

No equivalent.

GAMMADIST
^^^^^^^^^

.. code-block:: text

  =GAMMADIST(x, alpha, beta, cumulative)

Returns the gamma distribution.

No equivalent.

GAMMAINV
^^^^^^^^

.. code-block:: text

  =GAMMAINV(probability, alpha, beta)

Returns the inverse of the cumulative gamma distribution.

No equivalent.

HYPGEOMDIST
^^^^^^^^^^^

Returns the probability of a number of successes in a sample drawn without replacement.

.. code-block:: sql

  -- =HYPGEOMDIST(sample_s, number_sample, population_s, number_pop)
  VALUES (FACTORIAL(/*population_s*/) / (FACTORIAL(/*sample_s*/) * FACTORIAL(/*population_s*/ - /*sample_s*/)))
    * (FACTORIAL(/*number_pop*/ - /*population_s*/) / (FACTORIAL(/*number_sample*/ - /*sample_s*/)
      * FACTORIAL(/*number_pop*/ - /*population_s*/ - /*number_sample*/ + /*sample_s*/)))
    / (FACTORIAL(/*number_pop*/) / (FACTORIAL(/*number_sample*/) * FACTORIAL(/*number_pop*/ - /*number_sample*/)) * 1e0);
  -- =HYPGEOMDIST(1, 2, 3, 6)
  VALUES (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
    * (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
    / (FACTORIAL(6) / (FACTORIAL(2) * FACTORIAL(4)) * 1e0);
  -- COL1: 0.6e0

This is COMBIN(3, 1) * COMBIN(3, 1) / COMBIN(6, 2), each written with FACTORIAL, and the 1e0 makes the last division approximate instead of an integer division.

LOGINV
^^^^^^

.. code-block:: text

  =LOGINV(probability, mean, standard_dev)

Returns the inverse of the cumulative lognormal distribution.

No equivalent.

LOGNORMDIST
^^^^^^^^^^^

Returns the cumulative lognormal distribution.

.. code-block:: sql

  -- =LOGNORMDIST(x, mean, standard_dev)
  VALUES 0.5 * ERFC(-(LN(/*x*/) - /*mean*/) / (/*standard_dev*/ * SQRT(2e0)));
  -- =LOGNORMDIST(2, 0, 1)
  VALUES 0.5 * ERFC(-(LN(2e0) - 0) / (1e0 * SQRT(2e0)));
  -- COL1: 0.755891404214e0

MODE
^^^^

Returns the most frequent value.

.. code-block:: sql

  -- =MODE(number1)
  SELECT MODE() WITHIN GROUP (ORDER BY /*number1*/) FROM /*table*/;
  -- =MODE(1, 2, 2, 3)
  SELECT MODE() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
  -- COL1: 2

On a tie this returns the first value in the ``ORDER BY`` order (the smallest
with ``ASC``), where the spreadsheet returns the one that comes first in the
sheet.

NEGBINOMDIST
^^^^^^^^^^^^

Returns the probability of a number of failures before a number of successes.

.. code-block:: sql

  -- =NEGBINOMDIST(number_f, number_s, probability_s)
  VALUES FACTORIAL(/*number_f*/ + /*number_s*/ - 1) / (FACTORIAL(/*number_s*/ - 1) * FACTORIAL(/*number_f*/))
    * POWER(/*probability_s*/, /*number_s*/) * POWER(1 - /*probability_s*/, /*number_f*/);
  -- =NEGBINOMDIST(2, 3, 0.5)
  VALUES FACTORIAL(2 + 3 - 1) / (FACTORIAL(3 - 1) * FACTORIAL(2))
    * POWER(0.5e0, 3) * POWER(1 - 0.5e0, 2);
  -- COL1: 0.1875e0

The binomial coefficient COMBIN(number_f + number_s - 1, number_s - 1) is written with FACTORIAL.

NORMDIST
^^^^^^^^

Returns the normal distribution.

.. code-block:: sql

  -- =NORMDIST(x, mean, standard_dev, TRUE)
  VALUES 0.5 * ERFC(-(/*x*/ - /*mean*/) / (/*standard_dev*/ * SQRT(2e0)));
  -- =NORMDIST(1, 0, 1, TRUE)
  VALUES 0.5 * ERFC(-(1 - 0) / (1e0 * SQRT(2e0)));
  -- COL1: 0.841344746069e0

  -- =NORMDIST(x, mean, standard_dev, FALSE)
  VALUES EXP(-POWER(/*x*/ - /*mean*/, 2) / (2 * POWER(/*standard_dev*/, 2))) / (/*standard_dev*/ * SQRT(2 * PI()));
  -- =NORMDIST(1, 0, 1, FALSE)
  VALUES EXP(-POWER(1 - 0, 2) / (2 * POWER(1e0, 2)))
    / (1e0 * SQRT(2 * PI()));
  -- COL1: 0.241970724519e0

NORMINV
^^^^^^^

.. code-block:: text

  =NORMINV(probability, mean, standard_dev)

Returns the inverse of the cumulative normal distribution.

No equivalent.

NORMSDIST
^^^^^^^^^

Returns the cumulative standard normal distribution.

.. code-block:: sql

  -- =NORMSDIST(z)
  VALUES 0.5 * ERFC(-/*z*/ / SQRT(2e0));
  -- =NORMSDIST(1)
  VALUES 0.5 * ERFC(-1e0 / SQRT(2e0));
  -- COL1: 0.841344746069e0

NORMSINV
^^^^^^^^

.. code-block:: text

  =NORMSINV(probability)

Returns the inverse of the cumulative standard normal distribution.

No equivalent.

PERCENTILE
^^^^^^^^^^

Returns the k-th percentile, interpolating between values.

.. code-block:: sql

  -- =PERCENTILE(array, k)
  SELECT PERCENTILE_CONT(/*k*/) WITHIN GROUP (ORDER BY /*array*/) FROM /*table*/;
  -- =PERCENTILE(B2:B5, 0.25)
  SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY y)
  FROM points;
  -- COL1: 3.575e0

PERCENTRANK
^^^^^^^^^^^

Returns the rank of a value as a fraction of the other values.

.. code-block:: sql

  -- =PERCENTRANK(array, x)
  SELECT TRUNC(COUNT(*) FILTER (WHERE /*array*/ < /*x*/) / (COUNT(*) - 1e0), 3) FROM /*table*/;
  -- =PERCENTRANK(C2:C5, 3)
  SELECT TRUNC(COUNT(*) FILTER (WHERE price < 3)
    / (COUNT(*) - 1e0), 3) FROM products;
  -- COL1: 0.666e0

This is only right when x is one of the values; the spreadsheet interpolates between values otherwise.

POISSON
^^^^^^^

Returns the Poisson probability of a number of events.

.. code-block:: sql

  -- =POISSON(x, mean, FALSE)
  VALUES EXP(-/*mean*/) * POWER(/*mean*/, /*x*/) / FACTORIAL(/*x*/);
  -- =POISSON(2, 3, FALSE)
  VALUES EXP(-3e0) * POWER(3e0, 2) / FACTORIAL(2);
  -- COL1: 0.224041807655e0

For cumulative TRUE, add up the terms for 0 to x.

QUARTILE
^^^^^^^^

Returns a quartile, interpolating between values.

.. code-block:: sql

  -- =QUARTILE(array, quart)
  SELECT PERCENTILE_CONT(/*quart*/ / 4e0) WITHIN GROUP (ORDER BY /*array*/) FROM /*table*/;
  -- =QUARTILE(B2:B5, 1)
  SELECT PERCENTILE_CONT(1 / 4e0) WITHIN GROUP (ORDER BY y)
  FROM points;
  -- COL1: 3.575e0

RANK
^^^^

Returns the rank of a number among other numbers, with ties sharing a rank.

.. code-block:: sql

  -- =RANK(number, ref)
  SELECT RANK(/*number*/) WITHIN GROUP (ORDER BY /*ref*/ DESC) FROM /*table*/;
  -- =RANK(3, C2:C5)
  SELECT RANK(3) WITHIN GROUP (ORDER BY price DESC)
  FROM products;
  -- COL1: 2

  -- =RANK(number, ref, 1)
  SELECT RANK(/*number*/) WITHIN GROUP (ORDER BY /*ref*/) FROM /*table*/;
  -- =RANK(3, C2:C5, 1)
  SELECT RANK(3) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 3

Use ORDER BY price (ascending) for order 1.

STDEV
^^^^^

Returns the standard deviation of a sample.

.. code-block:: sql

  -- =STDEV(number1)
  SELECT STDDEV_SAMP(/*number1*/) FROM /*table*/;
  -- =STDEV(B2:B5)
  SELECT STDDEV_SAMP(y) FROM points;
  -- COL1: 2.636285265293e0

STDEVP
^^^^^^

Returns the standard deviation of a whole population.

.. code-block:: sql

  -- =STDEVP(number1)
  SELECT STDDEV_POP(/*number1*/) FROM /*table*/;
  -- =STDEVP(B2:B5)
  SELECT STDDEV_POP(y) FROM points;
  -- COL1: 2.283090011366e0

TDIST
^^^^^

.. code-block:: text

  =TDIST(x, deg_freedom, tails)

Returns the one- or two-tailed Student's t-distribution.

No equivalent.

TINV
^^^^

.. code-block:: text

  =TINV(probability, deg_freedom)

Returns the inverse of the two-tailed Student's t-distribution.

No equivalent.

TTEST
^^^^^

.. code-block:: text

  =TTEST(array1, array2, tails, type)

Returns the p-value of a Student's t-test.

No equivalent.

VAR
^^^

Returns the variance of a sample.

.. code-block:: sql

  -- =VAR(number1)
  SELECT VAR_SAMP(/*number1*/) FROM /*table*/;
  -- =VAR(B2:B5)
  SELECT VAR_SAMP(y) FROM points;
  -- COL1: 6.95e0

VARP
^^^^

Returns the variance of a whole population.

.. code-block:: sql

  -- =VARP(number1)
  SELECT VAR_POP(/*number1*/) FROM /*table*/;
  -- =VARP(B2:B5)
  SELECT VAR_POP(y) FROM points;
  -- COL1: 5.2125e0

WEIBULL
^^^^^^^

Returns the Weibull distribution.

.. code-block:: sql

  -- =WEIBULL(x, alpha, beta, TRUE)
  VALUES 1 - EXP(-POWER(/*x*/ / /*beta*/, /*alpha*/));
  -- =WEIBULL(2, 1.5, 3, TRUE)
  VALUES 1 - EXP(-POWER(2 / 3e0, 1.5));
  -- COL1: 0.419770204025e0

For cumulative FALSE, use 1.5 / 3 * POWER(2 / 3e0, 0.5) * EXP(-POWER(2 / 3e0, 1.5)).

ZTEST
^^^^^

Returns the one-tailed p-value of a z-test.

.. code-block:: sql

  -- =ZTEST(array, x)
  SELECT 0.5 * ERFC((AVG(/*array*/) - /*x*/) / (STDDEV_SAMP(/*array*/) / SQRT(COUNT(/*array*/))) / SQRT(2e0)) FROM /*table*/;
  -- =ZTEST(B2:B5, 4)
  SELECT 0.5 * ERFC((AVG(y) - 4) / (STDDEV_SAMP(y) / SQRT(COUNT(y))) / SQRT(2e0))
  FROM points;
  -- COL1: 0.212848833428e0

  -- =ZTEST(array, x, sigma)
  SELECT 0.5 * ERFC((AVG(/*array*/) - /*x*/) / (/*sigma*/ / SQRT(COUNT(/*array*/))) / SQRT(2e0)) FROM /*table*/;
  -- =ZTEST(B2:B5, 4, 2)
  SELECT 0.5 * ERFC((AVG(y) - 4) / (2 / SQRT(COUNT(y))) / SQRT(2e0))
  FROM points;
  -- COL1: 0.146859056376e0

Cube
----

CUBEKPIMEMBER
^^^^^^^^^^^^^

.. code-block:: text

  =CUBEKPIMEMBER(connection, kpi_name, kpi_property, [caption])

Returns a property of a key performance indicator from a cube. Only in Excel.

No equivalent.

CUBEMEMBER
^^^^^^^^^^

.. code-block:: text

  =CUBEMEMBER(connection, member_expression, [caption])

Returns a member or tuple from a cube. Only in Excel.

No equivalent.

CUBEMEMBERPROPERTY
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  =CUBEMEMBERPROPERTY(connection, member_expression, property)

Returns the value of a property of a cube member. Only in Excel.

No equivalent.

CUBERANKEDMEMBER
^^^^^^^^^^^^^^^^

.. code-block:: text

  =CUBERANKEDMEMBER(connection, set_expression, rank, [caption])

Returns the member at a given rank in a cube set. Only in Excel.

No equivalent.

CUBESET
^^^^^^^

.. code-block:: text

  =CUBESET(connection, set_expression, [caption], [sort_order], [sort_by])

Defines a set of members or tuples on a cube server. Only in Excel.

No equivalent.

CUBESETCOUNT
^^^^^^^^^^^^

.. code-block:: text

  =CUBESETCOUNT(set)

Returns the number of items in a cube set. Only in Excel.

No equivalent.

CUBEVALUE
^^^^^^^^^

.. code-block:: text

  =CUBEVALUE(connection, [member_expression1], ...)

Returns an aggregated value from a cube. Only in Excel.

No equivalent.

Database
--------

DAVERAGE
^^^^^^^^

Returns the average of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DAVERAGE(database, field, criteria)
  SELECT AVG(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DAVERAGE(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT AVG(price) FROM products WHERE price > 1;
  -- COL1: 2.83

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DCOUNT
^^^^^^

Counts the numbers in a field over the rows that match the criteria.

.. code-block:: sql

  -- =DCOUNT(database, field, criteria)
  SELECT COUNT(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DCOUNT(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT COUNT(price) FROM products WHERE price > 1;
  -- COL1: 3

The criteria range F1:F2 becomes the WHERE. COUNT skips NULLs, like DCOUNT skips blank cells.

DCOUNTA
^^^^^^^

Counts the non-blank values in a field over the rows that match the criteria.

.. code-block:: sql

  -- =DCOUNTA(database, field, criteria)
  SELECT COUNT(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DCOUNTA(A1:D5, "name", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT COUNT(name) FROM products WHERE price > 1;
  -- COL1: 3

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DGET
^^^^

Returns the single value of a field from the one row that matches the criteria.

.. code-block:: sql

  -- =DGET(database, field, criteria)
  VALUES (SELECT /*field*/ FROM /*database*/ WHERE /*criteria*/);
  -- =DGET(A1:D5, "price", F1:F2), with F1 = "name" and F2 = "Cherry"
  VALUES (SELECT price FROM products WHERE name = 'Cherry');
  -- COL1: 4.00

The criteria range F1:F2 becomes the WHERE. Several matching rows is an error, like DGET, but no matching row gives NULL instead of an error.

DMAX
^^^^

Returns the largest value of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DMAX(database, field, criteria)
  SELECT MAX(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DMAX(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT MAX(price) FROM products WHERE price > 1;
  -- COL1: 4.00

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DMIN
^^^^

Returns the smallest value of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DMIN(database, field, criteria)
  SELECT MIN(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DMIN(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT MIN(price) FROM products WHERE price > 1;
  -- COL1: 1.50

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DPRODUCT
^^^^^^^^

Multiplies the values of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DPRODUCT(database, field, criteria)
  SELECT PRODUCT(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DPRODUCT(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT PRODUCT(price) FROM products WHERE price > 1;
  -- COL1: 18e0

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DSTDEV
^^^^^^

Returns the sample standard deviation of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DSTDEV(database, field, criteria)
  SELECT STDDEV_SAMP(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DSTDEV(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT STDDEV_SAMP(price) FROM products WHERE price > 1;
  -- COL1: 1.258305739212e0

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DSTDEVP
^^^^^^^

Returns the population standard deviation of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DSTDEVP(database, field, criteria)
  SELECT STDDEV_POP(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DSTDEVP(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT STDDEV_POP(price) FROM products WHERE price > 1;
  -- COL1: 1.027402333828e0

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DSUM
^^^^

Adds up a field over the rows that match the criteria.

.. code-block:: sql

  -- =DSUM(database, field, criteria)
  SELECT SUM(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DSUM(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT SUM(price) FROM products WHERE price > 1;
  -- COL1: 8.50

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DVAR
^^^^

Returns the sample variance of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DVAR(database, field, criteria)
  SELECT VAR_SAMP(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DVAR(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT VAR_SAMP(price) FROM products WHERE price > 1;
  -- COL1: 1.583333333333e0

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

DVARP
^^^^^

Returns the population variance of a field over the rows that match the criteria.

.. code-block:: sql

  -- =DVARP(database, field, criteria)
  SELECT VAR_POP(/*field*/) FROM /*database*/ WHERE /*criteria*/;
  -- =DVARP(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
  SELECT VAR_POP(price) FROM products WHERE price > 1;
  -- COL1: 1.055555555556e0

The criteria range F1:F2 holds the header "price" and the condition ">1", which becomes the WHERE.

Date and Time
-------------

✅ DATE
^^^^^^^

Builds a date from a year, a month and a day.

.. code-block:: sql

  -- =DATE(year, month, day)
  VALUES MAKE_DATE(/*year*/, /*month*/, /*day*/);
  -- =DATE(2024, 3, 5)
  VALUES MAKE_DATE(2024, 3, 5);
  -- COL1: 2024-03-05

A month or day that's out of range is an error (``MAKE_DATE(2024, 13, 1)`` is
a ``22007``), where a spreadsheet rolls it over into the next month or year.
With literal values, write ``DATE '2024-03-05'``.

DATEDIF
^^^^^^^

.. code-block:: text

  =DATEDIF(start_date, end_date, unit)

Counts the whole days, months or years between two dates.

No equivalent.

DATEVALUE
^^^^^^^^^

Converts text that looks like a date into a date.

.. code-block:: sql

  -- =DATEVALUE(date_text)
  VALUES CAST(/*date_text*/ AS DATE);
  -- =DATEVALUE("2024-03-05")
  VALUES CAST('2024-03-05' AS DATE);
  -- COL1: 2024-03-05

The text must be in the form ``YYYY-MM-DD``, and the result is a ``DATE``
rather than a serial number.

✅ DAY
^^^^^^

Returns the day of the month of a date, from 1 to 31.

.. code-block:: sql

  -- =DAY(serial_number)
  VALUES EXTRACT(DAY FROM /*serial_number*/);
  -- =DAY(DATE(2024, 3, 5))
  VALUES EXTRACT(DAY FROM DATE '2024-03-05');
  -- COL1: 5

It also works on a ``TIMESTAMP``.

DAYS
^^^^

.. code-block:: text

  =DAYS(end_date, start_date)

Counts the days between two dates.

No equivalent.

DAYS360
^^^^^^^

.. code-block:: text

  =DAYS360(start_date, end_date, [method])

Counts the days between two dates as if every month had 30 days.

No equivalent.

EDATE
^^^^^

.. code-block:: text

  =EDATE(start_date, months)

Returns the date a number of months before or after a date.

No equivalent.

EOMONTH
^^^^^^^

.. code-block:: text

  =EOMONTH(start_date, months)

Returns the last day of the month a number of months before or after a date.

No equivalent.

EPOCHTODATE
^^^^^^^^^^^

.. code-block:: text

  =EPOCHTODATE(timestamp, [unit])

Converts a Unix timestamp into a date and time. Only in Google Sheets.

No equivalent.

✅ HOUR
^^^^^^^

Returns the hour of a time, from 0 to 23.

.. code-block:: sql

  -- =HOUR(serial_number)
  VALUES EXTRACT(HOUR FROM /*serial_number*/);
  -- =HOUR("14:30:15")
  VALUES EXTRACT(HOUR FROM TIME '14:30:15');
  -- COL1: 14

It also works on a ``TIMESTAMP``. A ``DATE`` has no hour, so it's an error,
where a spreadsheet returns 0.

✅ ISOWEEKNUM
^^^^^^^^^^^^^

Returns the ISO week number of the year for a date.

.. code-block:: sql

  -- =ISOWEEKNUM(date)
  VALUES EXTRACT(WEEK FROM /*date*/);
  -- =ISOWEEKNUM(DATE(2027, 1, 1))
  VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
  -- COL1: 53

A week starts on a Monday and is in the year that has its Thursday, so January
1, 2027 is in the last week of 2026. ``EXTRACT(ISOYEAR FROM date)`` is that year.

✅ MINUTE
^^^^^^^^^

Returns the minute of a time, from 0 to 59.

.. code-block:: sql

  -- =MINUTE(serial_number)
  VALUES EXTRACT(MINUTE FROM /*serial_number*/);
  -- =MINUTE("14:30:15")
  VALUES EXTRACT(MINUTE FROM TIME '14:30:15');
  -- COL1: 30

It also works on a ``TIMESTAMP``.

✅ MONTH
^^^^^^^^

Returns the month of a date, from 1 to 12.

.. code-block:: sql

  -- =MONTH(serial_number)
  VALUES EXTRACT(MONTH FROM /*serial_number*/);
  -- =MONTH(DATE(2024, 3, 5))
  VALUES EXTRACT(MONTH FROM DATE '2024-03-05');
  -- COL1: 3

It also works on a ``TIMESTAMP``.

NETWORKDAYS
^^^^^^^^^^^

.. code-block:: text

  =NETWORKDAYS(start_date, end_date, [holidays])

Counts the working days between two dates, leaving out weekends and holidays.

No equivalent.

NETWORKDAYS.INTL
^^^^^^^^^^^^^^^^

.. code-block:: text

  =NETWORKDAYS.INTL(start_date, end_date, [weekend], [holidays])

Counts the working days between two dates, with a choice of which days are the
weekend.

No equivalent.

NOW
^^^

Returns the current date and time.

.. code-block:: sql

  -- =NOW()
  VALUES NOW();
  -- =NOW() > DATE(2020, 1, 1)
  VALUES NOW() > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

``NOW()`` includes the time zone. Use ``LOCALTIMESTAMP`` for the date and time
without it.

✅ SECOND
^^^^^^^^^

Returns the second of a time, from 0 to 59.

.. code-block:: sql

  -- =SECOND(serial_number)
  VALUES EXTRACT(SECOND FROM /*serial_number*/);
  -- =SECOND("14:30:15")
  VALUES EXTRACT(SECOND FROM TIME '14:30:15');
  -- COL1: 15

It also works on a ``TIMESTAMP``. The fraction of a second is kept, so
``EXTRACT(SECOND FROM TIME '14:30:15.75')`` is 15.75; use ``FLOOR`` for whole
seconds.

✅ TIME
^^^^^^^

Builds a time from an hour, a minute and a second.

.. code-block:: sql

  -- =TIME(hour, minute, second)
  VALUES MAKE_TIME(/*hour*/, /*minute*/, /*second*/);
  -- =TIME(14, 30, 5)
  VALUES MAKE_TIME(14, 30, 5);
  -- COL1: 14:30:05.000000

The result is a ``TIME(6)``, so the second can have a fraction. A value that's
out of range is an error (``MAKE_TIME(24, 0, 0)`` is a ``22007``), where a
spreadsheet rolls it over. With literal values, write ``TIME '14:30:05'``.

TIMEVALUE
^^^^^^^^^

Converts text that looks like a time into a time.

.. code-block:: sql

  -- =TIMEVALUE(time_text)
  VALUES CAST(/*time_text*/ AS TIME);
  -- =TIMEVALUE("14:30:15")
  VALUES CAST('14:30:15' AS TIME);
  -- COL1: 14:30:15

The text must be in the 24-hour form ``HH:MM:SS``, and the result is a ``TIME``
rather than a fraction of a day.

TODAY
^^^^^

Returns the current date.

.. code-block:: sql

  -- =TODAY()
  VALUES CURRENT_DATE;
  -- =TODAY() > DATE(2020, 1, 1)
  VALUES CURRENT_DATE > DATE '2020-01-01';
  -- COL1: TRUE

There are no parentheses after ``CURRENT_DATE``.

🔧 WEEKDAY
^^^^^^^^^^

Returns the day of the week of a date as a number.

.. code-block:: sql

  -- =WEEKDAY(serial_number)
  VALUES EXTRACT(DOW FROM /*serial_number*/) + 1;
  -- =WEEKDAY(DATE(2026, 11, 15))
  VALUES EXTRACT(DOW FROM DATE '2026-11-15') + 1;
  -- COL1: 1

  -- =WEEKDAY(serial_number, 2)
  VALUES EXTRACT(ISODOW FROM /*serial_number*/);
  -- =WEEKDAY(DATE(2026, 11, 15), 2)
  VALUES EXTRACT(ISODOW FROM DATE '2026-11-15');
  -- COL1: 7

  -- =WEEKDAY(serial_number, 3)
  VALUES EXTRACT(ISODOW FROM /*serial_number*/) - 1;
  -- =WEEKDAY(DATE(2026, 11, 15), 3)
  VALUES EXTRACT(ISODOW FROM DATE '2026-11-15') - 1;
  -- COL1: 6

2026-11-15 is a Sunday. ``DOW`` and ``ISODOW`` aren't in the SQL standard.

🔧 WEEKNUM
^^^^^^^^^^

Returns the week number of the year for a date.

.. code-block:: sql

  -- =WEEKNUM(serial_number)
  VALUES (EXTRACT(DOY FROM /*serial_number*/) - 1 + MOD(MOD(EXTRACT(DOW FROM /*serial_number*/) - EXTRACT(DOY FROM /*serial_number*/) + 1, 7) + 7, 7)) / 7 + 1;
  -- =WEEKNUM(DATE(2026, 11, 15))
  VALUES (EXTRACT(DOY FROM DATE '2026-11-15') - 1 + MOD(MOD(EXTRACT(DOW FROM DATE '2026-11-15') - EXTRACT(DOY FROM DATE '2026-11-15') + 1, 7) + 7, 7)) / 7 + 1;
  -- COL1: 47

  -- =WEEKNUM(serial_number, 21)
  VALUES EXTRACT(WEEK FROM /*serial_number*/);
  -- =WEEKNUM(DATE(2027, 1, 1), 21)
  VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
  -- COL1: 53

The first week is the one with January 1, and a week starts on a Sunday. The
``MOD`` is the day of the week of January 1. With 21, it's the ISO 8601 week,
which is ``WEEK``.

WORKDAY
^^^^^^^

.. code-block:: text

  =WORKDAY(start_date, days, [holidays])

Returns the date a number of working days before or after a date.

No equivalent.

WORKDAY.INTL
^^^^^^^^^^^^

.. code-block:: text

  =WORKDAY.INTL(start_date, days, [weekend], [holidays])

Returns the date a number of working days before or after a date, with a choice
of which days are the weekend.

No equivalent.

✅ YEAR
^^^^^^^

Returns the year of a date.

.. code-block:: sql

  -- =YEAR(serial_number)
  VALUES EXTRACT(YEAR FROM /*serial_number*/);
  -- =YEAR(DATE(2024, 3, 5))
  VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
  -- COL1: 2024

It also works on a ``TIMESTAMP``.

YEARFRAC
^^^^^^^^

.. code-block:: text

  =YEARFRAC(start_date, end_date, [basis])

Returns the fraction of a year between two dates.

No equivalent.

Engineering
-----------

BESSELI
^^^^^^^

.. code-block:: text

  =BESSELI(x, n)

Returns the modified Bessel function In(x).

No equivalent.

BESSELJ
^^^^^^^

.. code-block:: text

  =BESSELJ(x, n)

Returns the Bessel function Jn(x).

No equivalent.

BESSELK
^^^^^^^

.. code-block:: text

  =BESSELK(x, n)

Returns the modified Bessel function Kn(x).

No equivalent.

BESSELY
^^^^^^^

.. code-block:: text

  =BESSELY(x, n)

Returns the Bessel function Yn(x), also called the Weber or Neumann function.

No equivalent.

BIN2DEC
^^^^^^^

.. code-block:: text

  =BIN2DEC(number)

Converts a binary number written as text to a decimal number.

No equivalent.

BIN2HEX
^^^^^^^

.. code-block:: text

  =BIN2HEX(number, [places])

Converts a binary number to hexadecimal text.

No equivalent.

BIN2OCT
^^^^^^^

.. code-block:: text

  =BIN2OCT(number, [places])

Converts a binary number to octal text.

No equivalent.

BITAND
^^^^^^

.. code-block:: text

  =BITAND(number1, number2)

Returns the bitwise AND of two whole numbers.

No equivalent.

BITLSHIFT
^^^^^^^^^

Shifts the bits of a number to the left, which multiplies it by a power of 2.

.. code-block:: sql

  -- =BITLSHIFT(number, shift_amount)
  VALUES CAST(/*number*/ * POWER(2, /*shift_amount*/) AS BIGINT);
  -- =BITLSHIFT(13, 2)
  VALUES CAST(13 * POWER(2, 2) AS BIGINT);
  -- COL1: 52

A negative ``shift_amount`` shifts right in a spreadsheet; use the BITRSHIFT
expression for that.

BITOR
^^^^^

.. code-block:: text

  =BITOR(number1, number2)

Returns the bitwise OR of two whole numbers.

No equivalent.

BITRSHIFT
^^^^^^^^^

Shifts the bits of a number to the right, which divides it by a power of 2 and
drops the remainder.

.. code-block:: sql

  -- =BITRSHIFT(number, shift_amount)
  VALUES CAST(FLOOR(/*number*/ / POWER(2, /*shift_amount*/)) AS BIGINT);
  -- =BITRSHIFT(13, 2)
  VALUES CAST(FLOOR(13 / POWER(2, 2)) AS BIGINT);
  -- COL1: 3

BITXOR
^^^^^^

.. code-block:: text

  =BITXOR(number1, number2)

Returns the bitwise exclusive OR of two whole numbers.

No equivalent.

COMPLEX
^^^^^^^

Builds the text of a complex number from its real and imaginary parts.

.. code-block:: sql

  -- =COMPLEX(real_num, i_num)
  VALUES CAST(/*real_num*/ AS VARCHAR(20)) || '+' || CAST(/*i_num*/ AS VARCHAR(20)) || 'i';
  -- =COMPLEX(3, 4)
  VALUES CAST(3 AS VARCHAR(20)) || '+' || CAST(4 AS VARCHAR(20)) || 'i';
  -- COL1: 3+4i

vsql has no complex numbers, so this is only text. A negative imaginary part
gives ``3+-4i``, which the spreadsheet would write as ``3-4i``.

CONVERT
^^^^^^^

.. code-block:: text

  =CONVERT(number, from_unit, to_unit)

Converts a measurement from one unit to another, such as miles to kilometers.

No equivalent.

DEC2BIN
^^^^^^^

.. code-block:: text

  =DEC2BIN(number, [places])

Converts a decimal number to binary text.

No equivalent.

DEC2HEX
^^^^^^^

.. code-block:: text

  =DEC2HEX(number, [places])

Converts a decimal number to hexadecimal text.

No equivalent.

DEC2OCT
^^^^^^^

.. code-block:: text

  =DEC2OCT(number, [places])

Converts a decimal number to octal text.

No equivalent.

DELTA
^^^^^

Returns 1 when two numbers are equal and 0 otherwise.

.. code-block:: sql

  -- =DELTA(number1, number2)
  VALUES CASE WHEN /*number1*/ = /*number2*/ THEN 1 ELSE 0 END;
  -- =DELTA(5, 4)
  VALUES CASE WHEN 5 = 4 THEN 1 ELSE 0 END;
  -- COL1: 0

  -- =DELTA(number1)
  VALUES CASE WHEN /*number1*/ = 0 THEN 1 ELSE 0 END;
  -- =DELTA(0)
  VALUES CASE WHEN 0 = 0 THEN 1 ELSE 0 END;
  -- COL1: 1

ERF
^^^

Returns the error function, integrated between two limits.

.. code-block:: sql

  -- =ERF(lower_limit, upper_limit)
  VALUES ERF(/*upper_limit*/) - ERF(/*lower_limit*/);
  -- =ERF(0.5, 1)
  VALUES ERF(1) - ERF(0.5);
  -- COL1: 0.322200915137e0

  -- =ERF(lower_limit)
  VALUES ERF(/*lower_limit*/);
  -- =ERF(1)
  VALUES ERF(1);
  -- COL1: 0.84270079295e0

ERF.PRECISE
^^^^^^^^^^^

Returns the error function integrated from 0 to a value.

.. code-block:: sql

  -- =ERF.PRECISE(x)
  VALUES ERF(/*x*/);
  -- =ERF.PRECISE(1)
  VALUES ERF(1);
  -- COL1: 0.84270079295e0

ERFC
^^^^

Returns the complementary error function, which is 1 minus ERF.

.. code-block:: sql

  -- =ERFC(x)
  VALUES ERFC(/*x*/);
  -- =ERFC(1)
  VALUES ERFC(1);
  -- COL1: 0.15729920705e0

ERFC.PRECISE
^^^^^^^^^^^^

Returns the complementary error function integrated from a value to infinity.

.. code-block:: sql

  -- =ERFC.PRECISE(x)
  VALUES ERFC(/*x*/);
  -- =ERFC.PRECISE(1)
  VALUES ERFC(1);
  -- COL1: 0.15729920705e0

GESTEP
^^^^^^

Returns 1 when a number is at least a threshold and 0 otherwise.

.. code-block:: sql

  -- =GESTEP(number, step)
  VALUES CASE WHEN /*number*/ >= /*step*/ THEN 1 ELSE 0 END;
  -- =GESTEP(5, 4)
  VALUES CASE WHEN 5 >= 4 THEN 1 ELSE 0 END;
  -- COL1: 1

  -- =GESTEP(number)
  VALUES CASE WHEN /*number*/ >= 0 THEN 1 ELSE 0 END;
  -- =GESTEP(-1)
  VALUES CASE WHEN -1 >= 0 THEN 1 ELSE 0 END;
  -- COL1: 0

HEX2BIN
^^^^^^^

.. code-block:: text

  =HEX2BIN(number, [places])

Converts a hexadecimal number to binary text.

No equivalent.

HEX2DEC
^^^^^^^

.. code-block:: text

  =HEX2DEC(number)

Converts a hexadecimal number written as text to a decimal number.

No equivalent.

HEX2OCT
^^^^^^^

.. code-block:: text

  =HEX2OCT(number, [places])

Converts a hexadecimal number to octal text.

No equivalent.

IMABS
^^^^^

Returns the absolute value (modulus) of a complex number.

.. code-block:: sql

  -- =IMABS("a+bi")
  VALUES SQRT(/*a*/ * /*a*/ + /*b*/ * /*b*/);
  -- =IMABS("3+4i")
  VALUES SQRT(3e0 * 3 + 4 * 4);
  -- COL1: 5e0

vsql has no complex numbers, so keep the real and imaginary parts as two
numbers (or two columns).

IMAGINARY
^^^^^^^^^

.. code-block:: text

  =IMAGINARY(inumber)

Returns the imaginary part of a complex number.

No equivalent.

IMARGUMENT
^^^^^^^^^^

Returns the angle of a complex number, in radians.

.. code-block:: sql

  -- =IMARGUMENT("a+bi")
  VALUES ATAN2(/*b*/, /*a*/);
  -- =IMARGUMENT("3+4i")
  VALUES ATAN2(4e0, 3e0);
  -- COL1: 0.927295218002e0

The imaginary part comes first in ``ATAN2``.

IMCONJUGATE
^^^^^^^^^^^

.. code-block:: text

  =IMCONJUGATE(inumber)

Returns the complex conjugate of a complex number.

No equivalent.

IMCOS
^^^^^

Returns the cosine of a complex number.

.. code-block:: sql

  -- =IMCOS("a+bi")
  SELECT COS(/*a*/) * COSH(/*b*/) AS re, -SIN(/*a*/) * SINH(/*b*/) AS im;
  -- =IMCOS("1+2i")
  SELECT COS(1e0) * COSH(2e0) AS re, -SIN(1e0) * SINH(2e0) AS im;
  -- RE: 2.03272300702e0 IM: -3.051897799152e0

IMCOSH
^^^^^^

Returns the hyperbolic cosine of a complex number.

.. code-block:: sql

  -- =IMCOSH("a+bi")
  SELECT COSH(/*a*/) * COS(/*b*/) AS re, SINH(/*a*/) * SIN(/*b*/) AS im;
  -- =IMCOSH("1+2i")
  SELECT COSH(1e0) * COS(2e0) AS re, SINH(1e0) * SIN(2e0) AS im;
  -- RE: -0.642148124716e0 IM: 1.068607421383e0

IMCOT
^^^^^

.. code-block:: text

  =IMCOT(inumber)

Returns the cotangent of a complex number.

No equivalent.

IMCSC
^^^^^

.. code-block:: text

  =IMCSC(inumber)

Returns the cosecant of a complex number.

No equivalent.

IMCSCH
^^^^^^

.. code-block:: text

  =IMCSCH(inumber)

Returns the hyperbolic cosecant of a complex number.

No equivalent.

IMDIV
^^^^^

Divides one complex number by another.

.. code-block:: sql

  -- =IMDIV("a+bi", "c+di")
  SELECT (/*a*/ * /*c*/ + /*b*/ * /*d*/) / (/*c*/ * /*c*/ + /*d*/ * /*d*/) AS re,
         (/*b*/ * /*c*/ - /*a*/ * /*d*/) / (/*c*/ * /*c*/ + /*d*/ * /*d*/) AS im;
  -- =IMDIV("3+4i", "1-2i")
  SELECT (3e0 * 1 + 4 * -2) / (1 * 1 + -2 * -2) AS re,
         (4e0 * 1 - 3 * -2) / (1 * 1 + -2 * -2) AS im;
  -- RE: -1e0 IM: 2e0

IMEXP
^^^^^

Returns e raised to the power of a complex number.

.. code-block:: sql

  -- =IMEXP("a+bi")
  SELECT EXP(/*a*/) * COS(/*b*/) AS re, EXP(/*a*/) * SIN(/*b*/) AS im;
  -- =IMEXP("1+2i")
  SELECT EXP(1e0) * COS(2e0) AS re, EXP(1e0) * SIN(2e0) AS im;
  -- RE: -1.131204383757e0 IM: 2.471726672005e0

IMLN
^^^^

Returns the natural logarithm of a complex number.

.. code-block:: sql

  -- =IMLN("a+bi")
  SELECT LN(SQRT(/*a*/ * /*a*/ + /*b*/ * /*b*/)) AS re, ATAN2(/*b*/, /*a*/) AS im;
  -- =IMLN("3+4i")
  SELECT LN(SQRT(3e0 * 3 + 4 * 4)) AS re, ATAN2(4e0, 3e0) AS im;
  -- RE: 1.609437912434e0 IM: 0.927295218002e0

IMLOG10
^^^^^^^

Returns the base-10 logarithm of a complex number.

.. code-block:: sql

  -- =IMLOG10("a+bi")
  SELECT LOG10(SQRT(/*a*/ * /*a*/ + /*b*/ * /*b*/)) AS re, ATAN2(/*b*/, /*a*/) / LN(10e0) AS im;
  -- =IMLOG10("3+4i")
  SELECT LOG10(SQRT(3e0 * 3 + 4 * 4)) AS re, ATAN2(4e0, 3e0) / LN(10e0) AS im;
  -- RE: 0.698970004336e0 IM: 0.402719196273e0

IMLOG2
^^^^^^

Returns the base-2 logarithm of a complex number.

.. code-block:: sql

  -- =IMLOG2("a+bi")
  SELECT LOG(2e0, SQRT(/*a*/ * /*a*/ + /*b*/ * /*b*/)) AS re, ATAN2(/*b*/, /*a*/) / LN(2e0) AS im;
  -- =IMLOG2("3+4i")
  SELECT LOG(2e0, SQRT(3e0 * 3 + 4 * 4)) AS re, ATAN2(4e0, 3e0) / LN(2e0) AS im;
  -- RE: 2.321928094887e0 IM: 1.337804212451e0

IMPOWER
^^^^^^^

Raises a complex number to a real power.

.. code-block:: sql

  -- =IMPOWER("a+bi", number)
  SELECT POWER(/*a*/ * /*a*/ + /*b*/ * /*b*/, /*number*/ / 2e0) * COS(/*number*/ * ATAN2(/*b*/, /*a*/)) AS re,
         POWER(/*a*/ * /*a*/ + /*b*/ * /*b*/, /*number*/ / 2e0) * SIN(/*number*/ * ATAN2(/*b*/, /*a*/)) AS im;
  -- =IMPOWER("3+4i", 2)
  SELECT POWER(3e0 * 3 + 4 * 4, 2 / 2e0) * COS(2 * ATAN2(4e0, 3e0)) AS re,
         POWER(3e0 * 3 + 4 * 4, 2 / 2e0) * SIN(2 * ATAN2(4e0, 3e0)) AS im;
  -- RE: -7e0 IM: 24e0

IMPRODUCT
^^^^^^^^^

Multiplies complex numbers.

.. code-block:: sql

  -- =IMPRODUCT("a+bi", "c+di")
  SELECT /*a*/ * /*c*/ - /*b*/ * /*d*/ AS re, /*a*/ * /*d*/ + /*b*/ * /*c*/ AS im;
  -- =IMPRODUCT("3+4i", "1-2i")
  SELECT 3 * 1 - 4 * -2 AS re, 3 * -2 + 4 * 1 AS im;
  -- RE: 11 IM: -2

IMREAL
^^^^^^

.. code-block:: text

  =IMREAL(inumber)

Returns the real part of a complex number.

No equivalent.

IMSEC
^^^^^

.. code-block:: text

  =IMSEC(inumber)

Returns the secant of a complex number.

No equivalent.

IMSECH
^^^^^^

.. code-block:: text

  =IMSECH(inumber)

Returns the hyperbolic secant of a complex number.

No equivalent.

IMSIN
^^^^^

Returns the sine of a complex number.

.. code-block:: sql

  -- =IMSIN("a+bi")
  SELECT SIN(/*a*/) * COSH(/*b*/) AS re, COS(/*a*/) * SINH(/*b*/) AS im;
  -- =IMSIN("1+2i")
  SELECT SIN(1e0) * COSH(2e0) AS re, COS(1e0) * SINH(2e0) AS im;
  -- RE: 3.165778513216e0 IM: 1.959601041422e0

IMSINH
^^^^^^

Returns the hyperbolic sine of a complex number.

.. code-block:: sql

  -- =IMSINH("a+bi")
  SELECT SINH(/*a*/) * COS(/*b*/) AS re, COSH(/*a*/) * SIN(/*b*/) AS im;
  -- =IMSINH("1+2i")
  SELECT SINH(1e0) * COS(2e0) AS re, COSH(1e0) * SIN(2e0) AS im;
  -- RE: -0.489056259041e0 IM: 1.403119250622e0

IMSQRT
^^^^^^

Returns the square root of a complex number.

.. code-block:: sql

  -- =IMSQRT("a+bi")
  SELECT POWER(/*a*/ * /*a*/ + /*b*/ * /*b*/, 0.25e0) * COS(ATAN2(/*b*/, /*a*/) / 2) AS re,
         POWER(/*a*/ * /*a*/ + /*b*/ * /*b*/, 0.25e0) * SIN(ATAN2(/*b*/, /*a*/) / 2) AS im;
  -- =IMSQRT("3+4i")
  SELECT POWER(3e0 * 3 + 4 * 4, 0.25e0) * COS(ATAN2(4e0, 3e0) / 2) AS re,
         POWER(3e0 * 3 + 4 * 4, 0.25e0) * SIN(ATAN2(4e0, 3e0) / 2) AS im;
  -- RE: 2e0 IM: 1e0

IMSUB
^^^^^

Subtracts one complex number from another.

.. code-block:: sql

  -- =IMSUB("a+bi", "c+di")
  SELECT /*a*/ - /*c*/ AS re, /*b*/ - /*d*/ AS im;
  -- =IMSUB("3+4i", "1-2i")
  SELECT 3 - 1 AS re, 4 - -2 AS im;
  -- RE: 2 IM: 6

IMSUM
^^^^^

Adds complex numbers.

.. code-block:: sql

  -- =IMSUM("a+bi", "c+di")
  SELECT /*a*/ + /*c*/ AS re, /*b*/ + /*d*/ AS im;
  -- =IMSUM("3+4i", "1-2i")
  SELECT 3 + 1 AS re, 4 + -2 AS im;
  -- RE: 4 IM: 2

With the parts in two columns, ``SUM(re)`` and ``SUM(im)`` add a whole range.

IMTAN
^^^^^

.. code-block:: text

  =IMTAN(inumber)

Returns the tangent of a complex number.

No equivalent.

OCT2BIN
^^^^^^^

.. code-block:: text

  =OCT2BIN(number, [places])

Converts an octal number to binary text.

No equivalent.

OCT2DEC
^^^^^^^

.. code-block:: text

  =OCT2DEC(number)

Converts an octal number written as text to a decimal number.

No equivalent.

OCT2HEX
^^^^^^^

.. code-block:: text

  =OCT2HEX(number, [places])

Converts an octal number to hexadecimal text.

No equivalent.

Financial
---------

ACCRINT
^^^^^^^

.. code-block:: text

  =ACCRINT(issue, first_interest, settlement, rate, par, frequency, [basis], [calc_method])

Returns the interest accrued on a security that pays periodic interest.

No equivalent.

ACCRINTM
^^^^^^^^

.. code-block:: text

  =ACCRINTM(issue, settlement, rate, par, [basis])

Returns the interest accrued on a security that pays interest at maturity.

No equivalent.

AMORDEGRC
^^^^^^^^^

.. code-block:: text

  =AMORDEGRC(cost, date_purchased, first_period, salvage, period, rate, [basis])

Returns the depreciation for a period under the French declining accounting system. Only in Excel.

No equivalent.

AMORLINC
^^^^^^^^

.. code-block:: text

  =AMORLINC(cost, date_purchased, first_period, salvage, period, rate, [basis])

Returns the depreciation for a period under the French linear accounting system.

No equivalent.

COUPDAYBS
^^^^^^^^^

.. code-block:: text

  =COUPDAYBS(settlement, maturity, frequency, [basis])

Returns the number of days from the start of the coupon period to the settlement date.

No equivalent.

COUPDAYS
^^^^^^^^

.. code-block:: text

  =COUPDAYS(settlement, maturity, frequency, [basis])

Returns the number of days in the coupon period that holds the settlement date.

No equivalent.

COUPDAYSNC
^^^^^^^^^^

.. code-block:: text

  =COUPDAYSNC(settlement, maturity, frequency, [basis])

Returns the number of days from the settlement date to the next coupon date.

No equivalent.

COUPNCD
^^^^^^^

.. code-block:: text

  =COUPNCD(settlement, maturity, frequency, [basis])

Returns the next coupon date after the settlement date.

No equivalent.

COUPNUM
^^^^^^^

.. code-block:: text

  =COUPNUM(settlement, maturity, frequency, [basis])

Returns the number of coupons payable between settlement and maturity.

No equivalent.

COUPPCD
^^^^^^^

.. code-block:: text

  =COUPPCD(settlement, maturity, frequency, [basis])

Returns the last coupon date before the settlement date.

No equivalent.

CUMIPMT
^^^^^^^

Returns the total interest paid on a loan between two periods.

.. code-block:: sql

  -- =CUMIPMT(rate, nper, pv, start_period, end_period, 0)
  SELECT ROUND(pmt * (e - s + 1) - (pmt + pv * r) * (POWER(1 + r, e) - POWER(1 + r, s - 1)) / r, 2)
  FROM (SELECT r, pv, s, e, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (/*rate*/, /*nper*/, /*pv*/, /*start_period*/, /*end_period*/)) AS a (r, n, pv, s, e)) AS b;
  -- =CUMIPMT(0.01, 12, 1000, 1, 6, 0)
  SELECT ROUND(pmt * (e - s + 1) - (pmt + pv * r) * (POWER(1 + r, e) - POWER(1 + r, s - 1)) / r, 2)
  FROM (SELECT r, pv, s, e, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (0.01e0, 12, 1000e0, 1, 6)) AS a (r, n, pv, s, e)) AS b;
  -- COL1: -48.01e0

This is for payments at the end of each period (type 0).

CUMPRINC
^^^^^^^^

Returns the total principal paid on a loan between two periods.

.. code-block:: sql

  -- =CUMPRINC(rate, nper, pv, start_period, end_period, 0)
  SELECT ROUND((pmt + pv * r) * (POWER(1 + r, e) - POWER(1 + r, s - 1)) / r, 2)
  FROM (SELECT r, pv, s, e, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (/*rate*/, /*nper*/, /*pv*/, /*start_period*/, /*end_period*/)) AS a (r, n, pv, s, e)) AS b;
  -- =CUMPRINC(0.01, 12, 1000, 1, 6, 0)
  SELECT ROUND((pmt + pv * r) * (POWER(1 + r, e) - POWER(1 + r, s - 1)) / r, 2)
  FROM (SELECT r, pv, s, e, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (0.01e0, 12, 1000e0, 1, 6)) AS a (r, n, pv, s, e)) AS b;
  -- COL1: -485.08e0

This is for payments at the end of each period (type 0).

DB
^^

Returns the depreciation of an asset for a period using the fixed-declining balance method.

.. code-block:: sql

  -- =DB(cost, salvage, life, period)
  SELECT ROUND(/*cost*/ * POWER(1 - r, /*period*/ - 1) * r, 2)
  FROM (VALUES (ROUND(1 - POWER(/*salvage*/ / /*cost*/, 1 / /*life*/), 3))) AS t (r);
  -- =DB(10000, 1000, 5, 2)
  SELECT ROUND(10000 * POWER(1 - r, 2 - 1) * r, 2)
  FROM (VALUES (ROUND(1 - POWER(1000 / 10000e0, 1 / 5e0), 3))) AS t (r);
  -- COL1: 2328.39e0

This is for a full first year (month 12). DB rounds the rate to three decimals, so the SQL does too.

DDB
^^^

Returns the depreciation of an asset for a period using the double-declining balance method.

.. code-block:: sql

  -- =DDB(cost, salvage, life, period)
  VALUES /*cost*/ * POWER(1 - 2 / /*life*/, /*period*/ - 1) * 2 / /*life*/;
  -- =DDB(10000, 1000, 5, 2)
  VALUES 10000 * POWER(1 - 2 / 5e0, 2 - 1) * 2 / 5e0;
  -- COL1: 2400e0

  -- =DDB(cost, salvage, life, period, factor)
  VALUES /*cost*/ * POWER(1 - /*factor*/ / /*life*/, /*period*/ - 1) * /*factor*/ / /*life*/;
  -- =DDB(10000, 1000, 5, 2, 1.5)
  VALUES 10000 * POWER(1 - 1.5 / 5e0, 2 - 1) * 1.5 / 5e0;
  -- COL1: 2100e0

DDB never takes the book value below salvage; the SQL doesn't check that, so late periods need a CASE.

DISC
^^^^

.. code-block:: text

  =DISC(settlement, maturity, pr, redemption, [basis])

Returns the discount rate of a security.

No equivalent.

DOLLARDE
^^^^^^^^

Converts a dollar price written as a fraction into a decimal number.

.. code-block:: sql

  -- =DOLLARDE(fractional_dollar, fraction)
  VALUES FLOOR(/*fractional_dollar*/) + MOD(/*fractional_dollar*/, 1) * POWER(10, CEIL(LOG10(/*fraction*/))) / /*fraction*/;
  -- =DOLLARDE(1.02, 16)
  VALUES FLOOR(1.02) + MOD(1.02, 1) * POWER(10, CEIL(LOG10(16))) / 16;
  -- COL1: 1.125e0

DOLLARFR
^^^^^^^^

Converts a decimal dollar price into one written as a fraction.

.. code-block:: sql

  -- =DOLLARFR(decimal_dollar, fraction)
  VALUES FLOOR(/*decimal_dollar*/) + MOD(/*decimal_dollar*/, 1) * /*fraction*/ / POWER(10, CEIL(LOG10(/*fraction*/)));
  -- =DOLLARFR(1.125, 16)
  VALUES FLOOR(1.125) + MOD(1.125, 1) * 16 / POWER(10, CEIL(LOG10(16)));
  -- COL1: 1.02e0

DURATION
^^^^^^^^

.. code-block:: text

  =DURATION(settlement, maturity, coupon, yld, frequency, [basis])

Returns the Macaulay duration of a security that pays periodic interest.

No equivalent.

EFFECT
^^^^^^

Returns the effective annual interest rate from a nominal rate.

.. code-block:: sql

  -- =EFFECT(nominal_rate, npery)
  VALUES POWER(1 + /*nominal_rate*/ / /*npery*/, /*npery*/) - 1;
  -- =EFFECT(0.0525, 4)
  VALUES POWER(1 + 0.0525e0 / 4, 4) - 1;
  -- COL1: 0.053542667371e0

FV
^^

Returns the future value of an investment with constant payments and rate.

.. code-block:: sql

  -- =FV(rate, nper, pmt, pv)
  VALUES ROUND(-(/*pv*/ * POWER(1 + /*rate*/, /*nper*/) + /*pmt*/ * (POWER(1 + /*rate*/, /*nper*/) - 1) / /*rate*/), 2);
  -- =FV(0.005, 12, -100, -1000)
  VALUES ROUND(-(-1000 * POWER(1 + 0.005e0, 12) + -100 * (POWER(1 + 0.005e0, 12) - 1) / 0.005), 2);
  -- COL1: 2295.23e0

  -- =FV(rate, nper, pmt)
  VALUES ROUND(-(/*pmt*/ * (POWER(1 + /*rate*/, /*nper*/) - 1) / /*rate*/), 2);
  -- =FV(0.005, 12, -100)
  VALUES ROUND(-(-100 * (POWER(1 + 0.005e0, 12) - 1) / 0.005), 2);
  -- COL1: 1233.56e0

This is for payments at the end of each period (type 0).

FVSCHEDULE
^^^^^^^^^^

Returns the future value of a principal after applying a series of interest rates.

.. code-block:: sql

  -- =FVSCHEDULE(principal, schedule)
  SELECT ROUND(/*principal*/ * PRODUCT(1 + /*schedule*/), 2) FROM /*table*/;
  -- =FVSCHEDULE(1000, {0.09, 0.11, 0.1})
  SELECT ROUND(1000 * PRODUCT(1 + r), 2)
  FROM (VALUES (0.09e0), (0.11e0), (0.1e0)) AS s (r);
  -- COL1: 1330.89e0

INTRATE
^^^^^^^

.. code-block:: text

  =INTRATE(settlement, maturity, investment, redemption, [basis])

Returns the interest rate of a fully invested security.

No equivalent.

IPMT
^^^^

Returns the interest part of a loan payment for a period.

.. code-block:: sql

  -- =IPMT(rate, per, nper, pv)
  SELECT ROUND(pmt - (pmt + pv * r) * POWER(1 + r, k - 1), 2)
  FROM (SELECT r, k, pv, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (/*rate*/, /*per*/, /*nper*/, /*pv*/)) AS a (r, k, n, pv)) AS b;
  -- =IPMT(0.01, 3, 12, 1000)
  SELECT ROUND(pmt - (pmt + pv * r) * POWER(1 + r, k - 1), 2)
  FROM (SELECT r, k, pv, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (0.01e0, 3, 12, 1000e0)) AS a (r, k, n, pv)) AS b;
  -- COL1: -8.42e0

This is for payments at the end of each period (type 0).

IRR
^^^

.. code-block:: text

  =IRR(values, [guess])

Returns the internal rate of return of a series of cash flows.

No equivalent.

ISPMT
^^^^^

Returns the interest paid in a period of a loan with even principal payments.

.. code-block:: sql

  -- =ISPMT(rate, per, nper, pv)
  VALUES ROUND(/*pv*/ * /*rate*/ * (/*per*/ / /*nper*/ - 1), 2);
  -- =ISPMT(0.01, 1, 12, 1000)
  VALUES ROUND(1000 * 0.01 * (1 / 12e0 - 1), 2);
  -- COL1: -9.17e0

MDURATION
^^^^^^^^^

.. code-block:: text

  =MDURATION(settlement, maturity, coupon, yld, frequency, [basis])

Returns the modified duration of a security.

No equivalent.

MIRR
^^^^

Returns the modified internal rate of return of a series of cash flows.

.. code-block:: sql

  -- =MIRR(values, finance_rate, reinvest_rate)
  SELECT POWER(SUM(/*values*/ * POWER(1 + /*reinvest_rate*/, /*count*/ - /*period*/)) FILTER (WHERE /*values*/ > 0)
    / -SUM(/*values*/ / POWER(1 + /*finance_rate*/, /*period*/ - 1)) FILTER (WHERE /*values*/ < 0), 1 / (/*count*/ - 1e0)) - 1
  FROM /*table*/;
  -- =MIRR(B2:B5, 0.1, 0.12)
  SELECT POWER(SUM(amount * POWER(1.12e0, 4 - n)) FILTER (WHERE amount > 0)
    / -SUM(amount / POWER(1.1e0, n - 1)) FILTER (WHERE amount < 0), 1 / 3e0) - 1
  FROM flows;
  -- COL1: 0.098156692446e0

The 4 is the number of periods and 3 is one less.

NOMINAL
^^^^^^^

Returns the nominal annual interest rate from an effective rate.

.. code-block:: sql

  -- =NOMINAL(effect_rate, npery)
  VALUES /*npery*/ * (POWER(1 + /*effect_rate*/, 1 / /*npery*/) - 1);
  -- =NOMINAL(0.053543, 4)
  VALUES 4 * (POWER(1 + 0.053543e0, 1 / 4e0) - 1);
  -- COL1: 0.052500319868e0

NPER
^^^^

Returns the number of periods needed to pay off a loan.

.. code-block:: sql

  -- =NPER(rate, pmt, pv)
  VALUES -LN(1 + /*pv*/ * /*rate*/ / /*pmt*/) / LN(1 + /*rate*/);
  -- =NPER(0.01, -100, 1000)
  VALUES -LN(1 + 1000 * 0.01e0 / -100) / LN(1 + 0.01e0);
  -- COL1: 10.588644459423e0

This is for payments at the end of each period with no future value.

NPV
^^^

Returns the net present value of a series of cash flows at a discount rate.

.. code-block:: sql

  -- =NPV(rate, value1)
  SELECT SUM(/*value1*/ / POWER(1 + /*rate*/, /*period*/)) FROM /*table*/;
  -- =NPV(0.1, B2:B5)
  SELECT SUM(amount / POWER(1 + 0.1e0, n)) FROM flows;
  -- COL1: -1.912437675022e0

The period number comes from the n column, where NPV uses the position in the range.

ODDFPRICE
^^^^^^^^^

.. code-block:: text

  =ODDFPRICE(settlement, maturity, issue, first_coupon, rate, yld, redemption, frequency, [basis])

Returns the price of a security with an odd first period. Only in Excel.

No equivalent.

ODDFYIELD
^^^^^^^^^

.. code-block:: text

  =ODDFYIELD(settlement, maturity, issue, first_coupon, rate, pr, redemption, frequency, [basis])

Returns the yield of a security with an odd first period. Only in Excel.

No equivalent.

ODDLPRICE
^^^^^^^^^

.. code-block:: text

  =ODDLPRICE(settlement, maturity, last_interest, rate, yld, redemption, frequency, [basis])

Returns the price of a security with an odd last period. Only in Excel.

No equivalent.

ODDLYIELD
^^^^^^^^^

.. code-block:: text

  =ODDLYIELD(settlement, maturity, last_interest, rate, pr, redemption, frequency, [basis])

Returns the yield of a security with an odd last period. Only in Excel.

No equivalent.

PDURATION
^^^^^^^^^

Returns the number of periods an investment needs to reach a value.

.. code-block:: sql

  -- =PDURATION(rate, pv, fv)
  VALUES LN(/*fv*/ / /*pv*/) / LN(1 + /*rate*/);
  -- =PDURATION(0.025, 2000, 2200)
  VALUES LN(2200 / 2000e0) / LN(1 + 0.025e0);
  -- COL1: 3.859866162623e0

PMT
^^^

Returns the payment per period of a loan with constant payments and rate.

.. code-block:: sql

  -- =PMT(rate, nper, pv)
  VALUES ROUND(-/*pv*/ * /*rate*/ / (1 - POWER(1 + /*rate*/, -/*nper*/)), 2);
  -- =PMT(0.01, 12, 1000)
  VALUES ROUND(-1000 * 0.01e0 / (1 - POWER(1 + 0.01e0, -12)), 2);
  -- COL1: -88.85e0

This is for payments at the end of each period with no future value.

PPMT
^^^^

Returns the principal part of a loan payment for a period.

.. code-block:: sql

  -- =PPMT(rate, per, nper, pv)
  SELECT ROUND((pmt + pv * r) * POWER(1 + r, k - 1), 2)
  FROM (SELECT r, k, pv, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (/*rate*/, /*per*/, /*nper*/, /*pv*/)) AS a (r, k, n, pv)) AS b;
  -- =PPMT(0.01, 3, 12, 1000)
  SELECT ROUND((pmt + pv * r) * POWER(1 + r, k - 1), 2)
  FROM (SELECT r, k, pv, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
        FROM (VALUES (0.01e0, 3, 12, 1000e0)) AS a (r, k, n, pv)) AS b;
  -- COL1: -80.43e0

This is for payments at the end of each period (type 0).

PRICE
^^^^^

.. code-block:: text

  =PRICE(settlement, maturity, rate, yld, redemption, frequency, [basis])

Returns the price per 100 face value of a security that pays periodic interest.

No equivalent.

PRICEDISC
^^^^^^^^^

.. code-block:: text

  =PRICEDISC(settlement, maturity, discount, redemption, [basis])

Returns the price per 100 face value of a discounted security.

No equivalent.

PRICEMAT
^^^^^^^^

.. code-block:: text

  =PRICEMAT(settlement, maturity, issue, rate, yld, [basis])

Returns the price per 100 face value of a security that pays interest at maturity.

No equivalent.

PV
^^

Returns the present value of a series of equal future payments.

.. code-block:: sql

  -- =PV(rate, nper, pmt)
  VALUES ROUND(-(/*pmt*/ * (1 - POWER(1 + /*rate*/, -/*nper*/)) / /*rate*/), 2);
  -- =PV(0.005, 12, -100)
  VALUES ROUND(-(-100 * (1 - POWER(1 + 0.005e0, -12)) / 0.005), 2);
  -- COL1: 1161.89e0

This is for payments at the end of each period with no future value.

RATE
^^^^

.. code-block:: text

  =RATE(nper, pmt, pv, [fv], [type], [guess])

Returns the interest rate per period of a loan or annuity.

No equivalent.

RECEIVED
^^^^^^^^

.. code-block:: text

  =RECEIVED(settlement, maturity, investment, discount, [basis])

Returns the amount received at maturity for a fully invested security.

No equivalent.

RRI
^^^

Returns the equivalent interest rate for the growth of an investment.

.. code-block:: sql

  -- =RRI(nper, pv, fv)
  VALUES POWER(/*fv*/ / /*pv*/, 1 / /*nper*/) - 1;
  -- =RRI(10, 1000, 2000)
  VALUES POWER(2000 / 1000e0, 1 / 10e0) - 1;
  -- COL1: 0.071773462536e0

SLN
^^^

Returns the straight-line depreciation of an asset for one period.

.. code-block:: sql

  -- =SLN(cost, salvage, life)
  VALUES (/*cost*/ - /*salvage*/) / /*life*/;
  -- =SLN(10000, 1000, 5)
  VALUES (10000 - 1000) / 5.0;
  -- COL1: 1800.0

STOCKHISTORY
^^^^^^^^^^^^

.. code-block:: text

  =STOCKHISTORY(stock, start_date, [end_date], [interval], [headers], [property0], ...)

Returns historical market data for a financial instrument. Only in Excel.

No equivalent.

SYD
^^^

Returns the sum-of-years' digits depreciation of an asset for a period.

.. code-block:: sql

  -- =SYD(cost, salvage, life, per)
  VALUES (/*cost*/ - /*salvage*/) * (/*life*/ - /*per*/ + 1) * 2 / (/*life*/ * (/*life*/ + 1));
  -- =SYD(10000, 1000, 5, 2)
  VALUES (10000 - 1000.0) * (5 - 2 + 1) * 2 / (5 * (5 + 1));
  -- COL1: 2400.0

TBILLEQ
^^^^^^^

.. code-block:: text

  =TBILLEQ(settlement, maturity, discount)

Returns the bond-equivalent yield of a Treasury bill.

No equivalent.

TBILLPRICE
^^^^^^^^^^

.. code-block:: text

  =TBILLPRICE(settlement, maturity, discount)

Returns the price per 100 face value of a Treasury bill.

No equivalent.

TBILLYIELD
^^^^^^^^^^

.. code-block:: text

  =TBILLYIELD(settlement, maturity, pr)

Returns the yield of a Treasury bill.

No equivalent.

VDB
^^^

.. code-block:: text

  =VDB(cost, salvage, life, start_period, end_period, [factor], [no_switch])

Returns the declining balance depreciation of an asset over any range of periods.

No equivalent.

XIRR
^^^^

.. code-block:: text

  =XIRR(values, dates, [guess])

Returns the internal rate of return of cash flows on irregular dates.

No equivalent.

XNPV
^^^^

.. code-block:: text

  =XNPV(rate, values, dates)

Returns the net present value of cash flows on irregular dates.

No equivalent.

YIELD
^^^^^

.. code-block:: text

  =YIELD(settlement, maturity, rate, pr, redemption, frequency, [basis])

Returns the yield of a security that pays periodic interest.

No equivalent.

YIELDDISC
^^^^^^^^^

.. code-block:: text

  =YIELDDISC(settlement, maturity, pr, redemption, [basis])

Returns the annual yield of a discounted security.

No equivalent.

YIELDMAT
^^^^^^^^

.. code-block:: text

  =YIELDMAT(settlement, maturity, issue, rate, pr, [basis])

Returns the annual yield of a security that pays interest at maturity.

No equivalent.

Google
------

AI
^^

.. code-block:: text

  =AI(prompt, [range])

Asks an AI model to generate or analyse text. Only in Google Sheets.

No equivalent.

ARRAYFORMULA
^^^^^^^^^^^^

Applies a formula to whole ranges instead of single cells. Only in Google Sheets.

.. code-block:: sql

  -- =ARRAYFORMULA(array_formula)
  SELECT /*array_formula, with a column for each range*/ FROM /*table*/;
  -- =ARRAYFORMULA(C2:C5 * D2:D5)
  SELECT price * COALESCE(qty, 0) AS total FROM products;
  -- TOTAL: 15.00
  -- TOTAL: 10.00
  -- TOTAL: 20.00
  -- TOTAL: 0.00

Every SQL expression already runs once per row. A blank cell counts as 0 in the sheet, so COALESCE turns the NULL into 0.

GOOGLEFINANCE
^^^^^^^^^^^^^

.. code-block:: text

  =GOOGLEFINANCE(ticker, [attribute], [start_date], [end_date], [interval])

Returns current or historical market data for a security. Only in Google Sheets.

No equivalent.

GOOGLETRANSLATE
^^^^^^^^^^^^^^^

.. code-block:: text

  =GOOGLETRANSLATE(text, [source_language], [target_language])

Translates text into another language. Only in Google Sheets.

No equivalent.

QUERY
^^^^^

Runs a query written in the Google Visualization query language over a range. Only in Google Sheets.

.. code-block:: sql

  -- =QUERY(data, query, 1)
  /*query, with FROM data and a column name for each letter*/;
  -- =QUERY(A1:D5, "select B where C > 1", 1)
  SELECT name FROM products WHERE price > 1;
  -- NAME: Apple
  -- NAME: Cherry
  -- NAME: Date

Columns are named instead of lettered.

SPARKLINE
^^^^^^^^^

.. code-block:: text

  =SPARKLINE(data, [options])

Draws a small chart inside a cell. Only in Google Sheets.

No equivalent.

Information
-----------

CELL
^^^^

.. code-block:: text

  =CELL(info_type, [reference])

Returns information about a cell, such as its address or format.

No equivalent.

ERROR.TYPE
^^^^^^^^^^

.. code-block:: text

  =ERROR.TYPE(error_val)

Returns a number for the kind of error value.

No equivalent.

INFO
^^^^

.. code-block:: text

  =INFO(type_text)

Returns information about the environment the workbook runs in. Only in Excel.

No equivalent.

ISBLANK
^^^^^^^

Checks whether a value is empty.

.. code-block:: sql

  -- =ISBLANK(value)
  VALUES /*value*/ IS NULL;
  -- =ISBLANK(D5)
  SELECT qty IS NULL AS blank FROM products WHERE sku = 'D4';
  -- BLANK: TRUE

ISEMAIL
^^^^^^^

Checks whether text looks like an email address. Only in Google Sheets.

.. code-block:: sql

  -- =ISEMAIL(value)
  VALUES /*value*/ SIMILAR TO '[A-Za-z0-9.]+@[A-Za-z0-9.]+.[A-Za-z]+';
  -- =ISEMAIL("jo.smith@example.com")
  VALUES 'jo.smith@example.com' SIMILAR TO '[A-Za-z0-9.]+@[A-Za-z0-9.]+.[A-Za-z]+';
  -- COL1: TRUE

This is a simple pattern rather than Google's exact rules. ``SIMILAR TO`` must
match the whole text, and ``.`` is an ordinary character in it.

ISERR
^^^^^

.. code-block:: text

  =ISERR(value)

Checks whether a value is any error other than ``#N/A``.

No equivalent.

ISERROR
^^^^^^^

.. code-block:: text

  =ISERROR(value)

Checks whether a value is any error.

No equivalent.

ISEVEN
^^^^^^

Checks whether a number is even.

.. code-block:: sql

  -- =ISEVEN(number)
  VALUES MOD(/*number*/, 2) = 0;
  -- =ISEVEN(10)
  VALUES MOD(10, 2) = 0;
  -- COL1: TRUE

ISFORMULA
^^^^^^^^^

.. code-block:: text

  =ISFORMULA(reference)

Checks whether a cell holds a formula.

No equivalent.

ISLOGICAL
^^^^^^^^^

.. code-block:: text

  =ISLOGICAL(value)

Checks whether a value is TRUE or FALSE.

No equivalent.

ISNA
^^^^

Checks whether a value is the ``#N/A`` error.

.. code-block:: sql

  -- =ISNA(value)
  VALUES /*value*/ IS NULL;
  -- =ISNA(MATCH("Fig", B2:B5, 0))
  VALUES (SELECT sku FROM products WHERE name = 'Fig') IS NULL;
  -- COL1: TRUE

A lookup that finds nothing gives ``NULL`` rather than ``#N/A``.

ISNONTEXT
^^^^^^^^^

.. code-block:: text

  =ISNONTEXT(value)

Checks whether a value is anything other than text.

No equivalent.

ISNUMBER
^^^^^^^^

.. code-block:: text

  =ISNUMBER(value)

Checks whether a value is a number.

No equivalent.

ISODD
^^^^^

Checks whether a number is odd.

.. code-block:: sql

  -- =ISODD(number)
  VALUES MOD(/*number*/, 2) <> 0;
  -- =ISODD(-3)
  VALUES MOD(-3, 2) <> 0;
  -- COL1: TRUE

ISOMITTED
^^^^^^^^^

.. code-block:: text

  =ISOMITTED(argument)

Checks whether an argument of a ``LAMBDA`` was left out. Only in Excel.

No equivalent.

ISREF
^^^^^

.. code-block:: text

  =ISREF(value)

Checks whether a value is a cell reference.

No equivalent.

ISTEXT
^^^^^^

.. code-block:: text

  =ISTEXT(value)

Checks whether a value is text.

No equivalent.

ISURL
^^^^^

Checks whether text looks like a web address. Only in Google Sheets.

.. code-block:: sql

  -- =ISURL(value)
  VALUES /*value*/ SIMILAR TO 'https?://%';
  -- =ISURL("https://example.com/a")
  VALUES 'https://example.com/a' SIMILAR TO 'https?://%';
  -- COL1: TRUE

This is a simple pattern rather than Google's exact rules, which also accept an
address without ``http://``.

N
^

Converts a value to a number, with TRUE as 1 and FALSE as 0.

.. code-block:: sql

  -- =N(value)
  VALUES CASE WHEN /*value*/ THEN 1 ELSE 0 END;
  -- =N(TRUE)
  VALUES CASE WHEN TRUE THEN 1 ELSE 0 END;
  -- COL1: 1

A number needs no conversion, and text would be 0 in a spreadsheet.

NA
^^

Returns the ``#N/A`` error value.

.. code-block:: sql

  -- =NA()
  VALUES CAST(NULL AS /*type*/);
  -- =NA()
  VALUES CAST(NULL AS INTEGER);
  -- COL1: NULL

``NULL`` takes the place of ``#N/A``, and it needs a ``CAST`` when its type
can't be worked out.

SHEET
^^^^^

.. code-block:: text

  =SHEET([value])

Returns the number of a sheet.

No equivalent.

SHEETS
^^^^^^

.. code-block:: text

  =SHEETS([reference])

Returns the number of sheets.

No equivalent.

TYPE
^^^^

.. code-block:: text

  =TYPE(value)

Returns a number for the kind of value, such as number, text or logical.

No equivalent.

Logical
-------

AND
^^^

Returns TRUE when every condition is true.

.. code-block:: sql

  -- =AND(logical1, logical2, ...)
  VALUES /*logical1*/ AND /*logical2*/ AND ...;
  -- =AND(2 > 1, 3 > 2)
  VALUES 2 > 1 AND 3 > 2;
  -- COL1: TRUE

For a whole range, such as ``=AND(C2:C5 > 0)``, use
``SELECT EVERY(price > 0) FROM products;``.

BYCOL
^^^^^

Applies a calculation to each column of a range.

.. code-block:: sql

  -- =BYCOL(array, LAMBDA(c, aggregate))
  SELECT /*aggregate of the first column*/, /*aggregate of the second column*/, ... FROM /*array*/;
  -- =BYCOL(A2:B5, LAMBDA(c, MAX(c)))
  SELECT MAX(x), MAX(y) FROM points;
  -- COL1: 4e0 COL2: 8.2e0

BYROW
^^^^^

Applies a calculation to each row of a range.

.. code-block:: sql

  -- =BYROW(array, LAMBDA(r, calculation))
  SELECT /*calculation on the columns*/ FROM /*array*/;
  -- =BYROW(C2:D4, LAMBDA(r, PRODUCT(r)))
  SELECT price * qty AS total FROM products WHERE qty IS NOT NULL ORDER BY sku;
  -- TOTAL: 15.00
  -- TOTAL: 10.00
  -- TOTAL: 20.00

FALSE
^^^^^

Returns the logical value FALSE.

.. code-block:: sql

  -- =FALSE()
  VALUES FALSE;
  -- =FALSE()
  VALUES FALSE;
  -- COL1: FALSE

IF
^^

Returns one value when a condition is true and another when it's false.

.. code-block:: sql

  -- =IF(logical_test, value_if_true, value_if_false)
  VALUES CASE WHEN /*logical_test*/ THEN /*value_if_true*/ ELSE /*value_if_false*/ END;
  -- =IF(2 > 1, "yes", "no")
  VALUES CASE WHEN 2 > 1 THEN 'yes' ELSE 'no' END;
  -- COL1: yes

IFERROR
^^^^^^^

.. code-block:: text

  =IFERROR(value, value_if_error)

Returns a fallback value when a calculation gives an error.

No equivalent.

IFNA
^^^^

Returns a fallback value when a calculation gives ``#N/A``.

.. code-block:: sql

  -- =IFNA(value, value_if_na)
  VALUES COALESCE(/*value*/, /*value_if_na*/);
  -- =IFNA(VLOOKUP("Fig", B2:C5, 2, FALSE), 0)
  VALUES COALESCE((SELECT price FROM products WHERE name = 'Fig'), 0);
  -- COL1: 0.00

A lookup that finds nothing gives ``NULL`` rather than ``#N/A``.

IFS
^^^

Returns the value for the first condition that is true.

.. code-block:: sql

  -- =IFS(logical_test1, value_if_true1, logical_test2, value_if_true2, ...)
  VALUES CASE WHEN /*logical_test1*/ THEN /*value_if_true1*/ WHEN /*logical_test2*/ THEN /*value_if_true2*/ ... END;
  -- =IFS(D2 < 10, "low", D2 >= 10, "ok")
  SELECT CASE WHEN qty < 10 THEN 'low' WHEN qty >= 10 THEN 'ok' END AS stock
  FROM products WHERE qty IS NOT NULL ORDER BY sku;
  -- STOCK: ok
  -- STOCK: ok
  -- STOCK: low

When no condition is true, the result is ``NULL`` rather than ``#N/A``.

LAMBDA
^^^^^^

.. code-block:: text

  =LAMBDA([parameter1, parameter2, ...], calculation)

Defines a reusable calculation with parameters.

No equivalent.

LET
^^^

Gives names to values so a calculation can use them.

.. code-block:: sql

  -- =LET(name1, name_value1, calculation)
  SELECT /*calculation*/ FROM (VALUES /*name_value1*/) AS t (/*name1*/);
  -- =LET(x, 5, x * x + x)
  SELECT x * x + x FROM (VALUES 5) AS t (x);
  -- COL1: 30

MAKEARRAY
^^^^^^^^^

Builds an array of a given size by calculating each element from its row and
column.

.. code-block:: sql

  -- =MAKEARRAY(rows, cols, LAMBDA(r, c, calculation))
  SELECT /*calculation with c = 1*/ AS c1, ..., /*calculation with c = cols*/ FROM (VALUES 1, ..., /*rows*/) AS t (r);
  -- =MAKEARRAY(2, 3, LAMBDA(r, c, r * c))
  SELECT r * 1 AS c1, r * 2 AS c2, r * 3 AS c3 FROM (VALUES 1, 2) AS t (r);
  -- C1: 1 C2: 2 C3: 3
  -- C1: 2 C2: 4 C3: 6

The number of columns is fixed by the query.

MAP
^^^

Applies a calculation to each value of a range.

.. code-block:: sql

  -- =MAP(array1, LAMBDA(v, calculation))
  SELECT /*calculation on array1*/ FROM /*table*/;
  -- =MAP(C2:C5, LAMBDA(p, p * 2))
  SELECT price * 2 FROM products ORDER BY sku;
  -- COL1: 3.00
  -- COL1: 0.50
  -- COL1: 8.00
  -- COL1: 6.00

NOT
^^^

Reverses a logical value.

.. code-block:: sql

  -- =NOT(logical)
  VALUES NOT (/*logical*/);
  -- =NOT(2 > 1)
  VALUES NOT (2 > 1);
  -- COL1: FALSE

OR
^^

Returns TRUE when any condition is true.

.. code-block:: sql

  -- =OR(logical1, logical2, ...)
  VALUES /*logical1*/ OR /*logical2*/ OR ...;
  -- =OR(2 > 1, 3 < 2)
  VALUES 2 > 1 OR 3 < 2;
  -- COL1: TRUE

For a whole range, such as ``=OR(C2:C5 > 3)``, use
``SELECT ANY(price > 3) FROM products;``.

REDUCE
^^^^^^

Combines the values of a range into one result, one value at a time.

.. code-block:: sql

  -- =REDUCE(0, array, LAMBDA(a, v, a + v))
  SELECT SUM(/*array*/) FROM /*table*/;
  -- =REDUCE(0, C2:C5, LAMBDA(a, v, a + v))
  SELECT SUM(price) FROM products;
  -- COL1: 8.75

Only a calculation that an aggregate such as ``SUM``, ``MAX`` or ``LISTAGG``
does can be written this way.

SCAN
^^^^

Combines the values of a range one at a time and returns every step along the
way.

.. code-block:: sql

  -- =SCAN(0, array, LAMBDA(a, v, a + v))
  SELECT (SELECT SUM(/*array*/) FROM /*table*/ AS p WHERE p./*key*/ <= /*table*/./*key*/) FROM /*table*/ ORDER BY /*key*/;
  -- =SCAN(0, C2:C5, LAMBDA(a, v, a + v))
  SELECT (SELECT SUM(price) FROM products AS p WHERE p.sku <= products.sku) AS total
  FROM products ORDER BY sku;
  -- TOTAL: 1.50
  -- TOTAL: 1.75
  -- TOTAL: 5.75
  -- TOTAL: 8.75

The order of the steps comes from a column, here ``sku``, rather than from the
position in the sheet.

SWITCH
^^^^^^

Compares a value against a list and returns the result for the first match.

.. code-block:: sql

  -- =SWITCH(expression, value1, result1, ..., default)
  VALUES CASE /*expression*/ WHEN /*value1*/ THEN /*result1*/ ... ELSE /*default*/ END;
  -- =SWITCH(2, 1, "one", 2, "two", "other")
  VALUES CASE 2 WHEN 1 THEN 'one' WHEN 2 THEN 'two' ELSE 'other' END;
  -- COL1: two

  -- =SWITCH(expression, value1, result1, value2, result2, ...)
  VALUES CASE /*expression*/ WHEN /*value1*/ THEN /*result1*/ WHEN /*value2*/ THEN /*result2*/ ... END;
  -- =SWITCH(3, 1, "one", 2, "two")
  VALUES CASE 3 WHEN 1 THEN 'one' WHEN 2 THEN 'two' END;
  -- COL1: NULL

TRUE
^^^^

Returns the logical value TRUE.

.. code-block:: sql

  -- =TRUE()
  VALUES TRUE;
  -- =TRUE()
  VALUES TRUE;
  -- COL1: TRUE

XOR
^^^

Returns TRUE when an odd number of conditions are true.

.. code-block:: sql

  -- =XOR(logical1, logical2)
  VALUES /*logical1*/ <> /*logical2*/;
  -- =XOR(TRUE, FALSE)
  VALUES TRUE <> FALSE;
  -- COL1: TRUE

``<>`` only works for two values.

Lookup and Reference
--------------------

ADDRESS
^^^^^^^

.. code-block:: text

  =ADDRESS(row_num, column_num, [abs_num], [a1], [sheet_text])

Returns a cell reference as text from row and column numbers.

No equivalent.

AREAS
^^^^^

.. code-block:: text

  =AREAS(reference)

Returns the number of areas in a reference.

No equivalent.

ARRAY_CONSTRAIN
^^^^^^^^^^^^^^^

Returns the top-left part of a range with a given number of rows and columns. Only in Google Sheets.

.. code-block:: sql

  -- =ARRAY_CONSTRAIN(input_range, num_rows, num_cols)
  SELECT /*the first num_cols columns*/ FROM /*input_range*/ ORDER BY /*key*/ FETCH FIRST /*num_rows*/ ROWS ONLY;
  -- =ARRAY_CONSTRAIN(A2:D5, 2, 2)
  SELECT sku, name FROM products ORDER BY sku FETCH FIRST 2 ROWS ONLY;
  -- SKU: A1 NAME: Apple
  -- SKU: B2 NAME: Banana

Rows have no fixed order without ORDER BY.

CHOOSE
^^^^^^

Returns the value at a given position in a list of values.

.. code-block:: sql

  -- =CHOOSE(index_num, value1, value2, ...)
  VALUES CASE /*index_num*/ WHEN 1 THEN /*value1*/ WHEN 2 THEN /*value2*/ ... END;
  -- =CHOOSE(2, "Apple", "Banana", "Cherry")
  VALUES CASE 2 WHEN 1 THEN 'Apple' WHEN 2 THEN 'Banana' WHEN 3 THEN 'Cherry' END;
  -- COL1: Banana

CHOOSECOLS
^^^^^^^^^^

Returns the chosen columns of an array.

.. code-block:: sql

  -- =CHOOSECOLS(array, col_num1, col_num2, ...)
  SELECT /*column col_num1*/, /*column col_num2*/, ... FROM /*array*/;
  -- =CHOOSECOLS(A2:D5, 2, 3)
  SELECT name, price FROM products ORDER BY sku;
  -- NAME: Apple PRICE: 1.50
  -- NAME: Banana PRICE: 0.25
  -- NAME: Cherry PRICE: 4.00
  -- NAME: Date PRICE: 3.00

CHOOSEROWS
^^^^^^^^^^

Returns the chosen rows of an array.

.. code-block:: sql

  -- =CHOOSEROWS(array, row_num1, row_num2, ...)
  SELECT * FROM /*array*/ WHERE (SELECT COUNT(*) FROM /*array*/ AS p WHERE p./*key*/ <= /*array*/./*key*/) IN (/*row_num1*/, /*row_num2*/, ...);
  -- =CHOOSEROWS(A2:D5, 1, 3)
  SELECT * FROM products
  WHERE (SELECT COUNT(*) FROM products AS p WHERE p.sku <= products.sku) IN (1, 3);
  -- SKU: A1 NAME: Apple PRICE: 1.50 QTY: 10
  -- SKU: C3 NAME: Cherry PRICE: 4.00 QTY: 5

The subquery numbers the rows in sku order.

COLUMN
^^^^^^

.. code-block:: text

  =COLUMN([reference])

Returns the column number of a reference.

No equivalent.

COLUMNS
^^^^^^^

.. code-block:: text

  =COLUMNS(array)

Returns the number of columns in a range or array.

No equivalent.

DROP
^^^^

Removes a number of rows or columns from the start or end of an array. Only in Excel.

.. code-block:: sql

  -- =DROP(array, rows)
  SELECT * FROM /*array*/ ORDER BY /*key*/ OFFSET /*rows*/ ROWS;
  -- =DROP(A2:D5, 2)
  SELECT * FROM products ORDER BY sku OFFSET 2 ROWS;
  -- SKU: C3 NAME: Cherry PRICE: 4.00 QTY: 5
  -- SKU: D4 NAME: Date PRICE: 3.00 QTY: NULL

EXPAND
^^^^^^

Pads an array out to a given number of rows and columns. Only in Excel.

.. code-block:: sql

  -- =EXPAND(array, rows, columns, pad_with)
  SELECT * FROM /*array*/ UNION ALL VALUES (/*pad_with*/, /*pad_with*/, ...);
  -- =EXPAND(A2:B3, 3, 2, "-")
  SELECT sku, name FROM products WHERE sku IN ('A1', 'B2')
  UNION ALL VALUES ('-', '-');
  -- SKU: A1 NAME: Apple
  -- SKU: B2 NAME: Banana
  -- SKU: - NAME: -

FILTER
^^^^^^

Returns the rows of an array that meet a condition.

.. code-block:: sql

  -- =FILTER(array, include)
  SELECT /*array*/ FROM /*table*/ WHERE /*include*/;
  -- =FILTER(B2:B5, C2:C5 > 1)
  SELECT name FROM products WHERE price > 1;
  -- NAME: Apple
  -- NAME: Cherry
  -- NAME: Date

FLATTEN
^^^^^^^

Puts the values of one or more ranges into a single column. Only in Google Sheets.

.. code-block:: sql

  -- =FLATTEN(range1, range2, ...)
  SELECT /*range1*/ FROM /*table*/ UNION ALL SELECT /*range2*/ FROM /*table*/ ...;
  -- =FLATTEN(A2:A3, B2:B3)
  SELECT sku FROM products WHERE sku IN ('A1', 'B2')
  UNION ALL SELECT name FROM products WHERE sku IN ('A1', 'B2');
  -- SKU: A1
  -- SKU: B2
  -- SKU: Apple
  -- SKU: Banana

FORMULATEXT
^^^^^^^^^^^

.. code-block:: text

  =FORMULATEXT(reference)

Returns the formula in a cell as text.

No equivalent.

GETPIVOTDATA
^^^^^^^^^^^^

Returns a value from a pivot table.

.. code-block:: sql

  -- =GETPIVOTDATA(data_field, pivot_table, field1, item1, ...)
  SELECT SUM(/*data_field*/) FROM /*table*/ WHERE /*field1*/ = /*item1*/ AND ...;
  -- =GETPIVOTDATA("qty", F1, "name", "Apple")
  SELECT SUM(qty) FROM products WHERE name = 'Apple';
  -- COL1: 10

Write the aggregate the pivot table would use, with WHERE for each field and item.

GROUPBY
^^^^^^^

Groups rows by a field and aggregates the values of each group. Only in Excel.

.. code-block:: sql

  -- =GROUPBY(row_fields, values, SUM)
  SELECT /*row_fields*/, SUM(/*values*/) FROM /*table*/ GROUP BY /*row_fields*/ ORDER BY /*row_fields*/;
  -- =GROUPBY(C2:C5 > 1, D2:D5, SUM)
  SELECT over_1, SUM(qty) AS qty
  FROM (SELECT price > 1 AS over_1, qty FROM products WHERE qty IS NOT NULL) AS t
  GROUP BY over_1 ORDER BY over_1;
  -- OVER_1: FALSE QTY: 40
  -- OVER_1: TRUE QTY: 15

GROUPBY also adds a grand total row; a second query or UNION ALL gives that.

HLOOKUP
^^^^^^^

Finds a value in the top row of a table and returns the value from a row below it.

.. code-block:: sql

  -- =HLOOKUP(lookup_value, table_array, row_index_num, FALSE)
  SELECT /*the column named lookup_value*/ FROM /*table_array*/ ORDER BY /*key*/ OFFSET /*row_index_num*/ - 2 ROWS FETCH FIRST 1 ROW ONLY;
  -- =HLOOKUP("price", A1:D5, 3, FALSE)
  SELECT price FROM products ORDER BY sku OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
  -- PRICE: 0.25

Headers are column names, so the lookup is just naming the column.

HSTACK
^^^^^^

Joins arrays side by side.

.. code-block:: sql

  -- =HSTACK(array1, array2, ...)
  SELECT /*array1*/, /*array2*/, ... FROM /*table*/ ORDER BY /*key*/;
  -- =HSTACK(A2:A5, C2:C5)
  SELECT sku, price FROM products ORDER BY sku;
  -- SKU: A1 PRICE: 1.50
  -- SKU: B2 PRICE: 0.25
  -- SKU: C3 PRICE: 4.00
  -- SKU: D4 PRICE: 3.00

Columns from different tables need a JOIN on a shared key instead.

HYPERLINK
^^^^^^^^^

.. code-block:: text

  =HYPERLINK(link_location, [friendly_name])

Makes a cell into a clickable link.

No equivalent.

IMAGE
^^^^^

.. code-block:: text

  =IMAGE(source, [alt_text], [sizing], [height], [width])

Shows an image inside a cell.

No equivalent.

INDEX
^^^^^

Returns the value at a given row and column of an array.

.. code-block:: sql

  -- =INDEX(array, row_num, column_num)
  SELECT /*column column_num*/ FROM /*array*/ ORDER BY /*key*/ OFFSET /*row_num*/ - 1 ROWS FETCH FIRST 1 ROW ONLY;
  -- =INDEX(A2:D5, 3, 2)
  SELECT name FROM products ORDER BY sku OFFSET 2 ROWS FETCH FIRST 1 ROW ONLY;
  -- NAME: Cherry

INDIRECT
^^^^^^^^

.. code-block:: text

  =INDIRECT(ref_text, [a1])

Returns the reference named by a text string.

No equivalent.

LOOKUP
^^^^^^

Finds the largest value not greater than the lookup value in a sorted range and returns the matching result.

.. code-block:: sql

  -- =LOOKUP(lookup_value, lookup_vector, result_vector)
  SELECT /*result_vector*/ FROM /*table*/ WHERE /*lookup_vector*/ <= /*lookup_value*/ ORDER BY /*lookup_vector*/ DESC FETCH FIRST 1 ROW ONLY;
  -- =LOOKUP("B9", A2:A5, B2:B5)
  SELECT name FROM products WHERE sku <= 'B9'
  ORDER BY sku DESC FETCH FIRST 1 ROW ONLY;
  -- NAME: Banana

MATCH
^^^^^

Returns the position of a value in a range.

.. code-block:: sql

  -- =MATCH(lookup_value, lookup_array, 0)
  SELECT (SELECT COUNT(*) FROM /*table*/ AS p WHERE p./*key*/ <= /*table*/./*key*/) FROM /*table*/ WHERE /*lookup_array*/ = /*lookup_value*/;
  -- =MATCH("Cherry", B2:B5, 0)
  SELECT (SELECT COUNT(*) FROM products AS p WHERE p.sku <= products.sku) AS pos
  FROM products WHERE name = 'Cherry';
  -- POS: 3

The position is counted in sku order.

OFFSET
^^^^^^

.. code-block:: text

  =OFFSET(reference, rows, cols, [height], [width])

Returns a reference shifted a number of rows and columns from another.

No equivalent.

PIVOTBY
^^^^^^^

.. code-block:: text

  =PIVOTBY(row_fields, col_fields, values, function, [field_headers], [row_total_depth], [row_sort_order], [col_total_depth], [col_sort_order], [filter_array], [relative_to])

Groups values by row and column fields into a pivot table. Only in Excel.

No equivalent.

ROW
^^^

.. code-block:: text

  =ROW([reference])

Returns the row number of a reference.

No equivalent.

ROWS
^^^^

Returns the number of rows in a range or array.

.. code-block:: sql

  -- =ROWS(array)
  SELECT COUNT(*) FROM /*array*/;
  -- =ROWS(A2:D5)
  SELECT COUNT(*) FROM products;
  -- COL1: 4

RTD
^^^

.. code-block:: text

  =RTD(prog_id, server, topic1, [topic2], ...)

Returns data from a real-time data server. Only in Excel.

No equivalent.

SORT
^^^^

Sorts the rows of an array.

.. code-block:: sql

  -- =SORT(array, sort_index, -1)
  SELECT * FROM /*array*/ ORDER BY /*column sort_index*/ DESC;
  -- =SORT(A2:B5, 2, -1)
  SELECT sku, name FROM products ORDER BY name DESC;
  -- SKU: D4 NAME: Date
  -- SKU: C3 NAME: Cherry
  -- SKU: B2 NAME: Banana
  -- SKU: A1 NAME: Apple

  -- =SORT(array, sort_index)
  SELECT * FROM /*array*/ ORDER BY /*column sort_index*/;
  -- =SORT(A2:B5, 2)
  SELECT sku, name FROM products ORDER BY name;
  -- SKU: A1 NAME: Apple
  -- SKU: B2 NAME: Banana
  -- SKU: C3 NAME: Cherry
  -- SKU: D4 NAME: Date

SORTBY
^^^^^^

Sorts an array by the values of another array. Only in Excel.

.. code-block:: sql

  -- =SORTBY(array, by_array1, -1)
  SELECT /*array*/ FROM /*table*/ ORDER BY /*by_array1*/ DESC;
  -- =SORTBY(B2:B5, C2:C5, -1)
  SELECT name FROM products ORDER BY price DESC;
  -- NAME: Cherry
  -- NAME: Date
  -- NAME: Apple
  -- NAME: Banana

  -- =SORTBY(array, by_array1)
  SELECT /*array*/ FROM /*table*/ ORDER BY /*by_array1*/;
  -- =SORTBY(B2:B5, C2:C5)
  SELECT name FROM products ORDER BY price;
  -- NAME: Banana
  -- NAME: Apple
  -- NAME: Date
  -- NAME: Cherry

SORTN
^^^^^

Returns the first n rows of a range after sorting. Only in Google Sheets.

.. code-block:: sql

  -- =SORTN(range, n, 0, sort_column1, FALSE)
  SELECT /*range*/ FROM /*table*/ ORDER BY /*sort_column1*/ DESC FETCH FIRST /*n*/ ROWS ONLY;
  -- =SORTN(B2:B5, 2, 0, C2:C5, FALSE)
  SELECT name FROM products ORDER BY price DESC FETCH FIRST 2 ROWS ONLY;
  -- NAME: Cherry
  -- NAME: Date

TAKE
^^^^

Returns a number of rows or columns from the start or end of an array. Only in Excel.

.. code-block:: sql

  -- =TAKE(array, rows)
  SELECT * FROM /*array*/ ORDER BY /*key*/ FETCH FIRST /*rows*/ ROWS ONLY;
  -- =TAKE(B2:B5, 2)
  SELECT name FROM products ORDER BY sku FETCH FIRST 2 ROWS ONLY;
  -- NAME: Apple
  -- NAME: Banana

A negative count takes from the end, which is ORDER BY … DESC.

TOCOL
^^^^^

Returns the values of an array as a single column.

.. code-block:: sql

  -- =TOCOL(array)
  SELECT CASE c.i WHEN 1 THEN /*first column*/ ELSE /*second column*/ END FROM /*array*/ JOIN (VALUES (1), (2)) AS c (i) ON TRUE ORDER BY /*key*/, c.i;
  -- =TOCOL(A2:B3)
  SELECT CASE c.i WHEN 1 THEN sku ELSE name END AS v
  FROM products JOIN (VALUES (1), (2)) AS c (i) ON TRUE
  WHERE sku IN ('A1', 'B2') ORDER BY sku, c.i;
  -- V: A1
  -- V: Apple
  -- V: B2
  -- V: Banana

TOROW
^^^^^

Returns the values of an array as a single row.

.. code-block:: sql

  -- =TOROW(array)
  SELECT LISTAGG(/*array*/, ', ') WITHIN GROUP (ORDER BY /*key*/) FROM /*table*/;
  -- =TOROW(B2:B5)
  SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY sku) FROM products;
  -- COL1: Apple, Banana, Cherry, Date

This returns one text value, not one column per value.

TRANSPOSE
^^^^^^^^^

.. code-block:: text

  =TRANSPOSE(array)

Swaps the rows and columns of an array.

No equivalent.

TRIMRANGE
^^^^^^^^^

.. code-block:: text

  =TRIMRANGE(range, [trim_rows], [trim_cols])

Removes empty rows and columns from the edges of a range. Only in Excel.

No equivalent.

UNIQUE
^^^^^^

Returns the distinct values of a range.

.. code-block:: sql

  -- =UNIQUE(array)
  SELECT DISTINCT /*array*/ FROM /*table*/;
  -- =UNIQUE(C2:C5 > 1)
  SELECT DISTINCT price > 1 AS over_1 FROM products;
  -- OVER_1: TRUE
  -- OVER_1: FALSE

With exactly_once, use GROUP BY with HAVING COUNT(*) = 1 instead.

VLOOKUP
^^^^^^^

Finds a value in the first column of a table and returns the value from another column of that row.

.. code-block:: sql

  -- =VLOOKUP(lookup_value, table_array, col_index_num, FALSE)
  VALUES (SELECT /*column col_index_num*/ FROM /*table_array*/ WHERE /*first column*/ = /*lookup_value*/);
  -- =VLOOKUP("C3", A2:D5, 3, FALSE)
  VALUES (SELECT price FROM products WHERE sku = 'C3');
  -- COL1: 4.00

If several rows match, the subquery is an error, where VLOOKUP takes the first one. No match gives NULL, not #N/A.

VSTACK
^^^^^^

Stacks arrays on top of each other.

.. code-block:: sql

  -- =VSTACK(array1, array2, ...)
  SELECT * FROM /*array1*/ UNION ALL SELECT * FROM /*array2*/ ...;
  -- =VSTACK(A2:B3, A4:B5)
  SELECT sku, name FROM products WHERE sku IN ('A1', 'B2')
  UNION ALL SELECT sku, name FROM products WHERE sku IN ('C3', 'D4');
  -- SKU: A1 NAME: Apple
  -- SKU: B2 NAME: Banana
  -- SKU: C3 NAME: Cherry
  -- SKU: D4 NAME: Date

WRAPCOLS
^^^^^^^^

.. code-block:: text

  =WRAPCOLS(vector, wrap_count, [pad_with])

Wraps a row or column of values into columns of a given length.

No equivalent.

WRAPROWS
^^^^^^^^

.. code-block:: text

  =WRAPROWS(vector, wrap_count, [pad_with])

Wraps a row or column of values into rows of a given length.

No equivalent.

XLOOKUP
^^^^^^^

Finds a value in a range and returns the matching value from another range.

.. code-block:: sql

  -- =XLOOKUP(lookup_value, lookup_array, return_array, if_not_found)
  VALUES COALESCE((SELECT /*return_array*/ FROM /*table*/ WHERE /*lookup_array*/ = /*lookup_value*/), /*if_not_found*/);
  -- =XLOOKUP("E5", A2:A5, B2:B5, "none")
  VALUES COALESCE((SELECT name FROM products WHERE sku = 'E5'), 'none');
  -- COL1: none

  -- =XLOOKUP(lookup_value, lookup_array, return_array)
  VALUES (SELECT /*return_array*/ FROM /*table*/ WHERE /*lookup_array*/ = /*lookup_value*/);
  -- =XLOOKUP("C3", A2:A5, B2:B5)
  VALUES (SELECT name FROM products WHERE sku = 'C3');
  -- COL1: Cherry

If several rows match, the subquery is an error, where XLOOKUP takes the first one.

XMATCH
^^^^^^

Returns the position of a value in a range or array.

.. code-block:: sql

  -- =XMATCH(lookup_value, lookup_array)
  SELECT (SELECT COUNT(*) FROM /*table*/ AS p WHERE p./*key*/ <= /*table*/./*key*/) FROM /*table*/ WHERE /*lookup_array*/ = /*lookup_value*/;
  -- =XMATCH("Cherry", B2:B5)
  SELECT (SELECT COUNT(*) FROM products AS p WHERE p.sku <= products.sku) AS pos
  FROM products WHERE name = 'Cherry';
  -- POS: 3

The position is counted in sku order.

Math and Trigonometry
---------------------

ABS
^^^

Returns the absolute value of a number.

.. code-block:: sql

  -- =ABS(number)
  VALUES ABS(/*number*/);
  -- =ABS(-4)
  VALUES ABS(-4);
  -- COL1: 4

ACOS
^^^^

Returns the arccosine of a number, in radians.

.. code-block:: sql

  -- =ACOS(number)
  VALUES ACOS(/*number*/);
  -- =ACOS(0.5)
  VALUES ACOS(0.5e0);
  -- COL1: 1.047197551197e0

ACOSH
^^^^^

Returns the inverse hyperbolic cosine of a number.

.. code-block:: sql

  -- =ACOSH(number)
  VALUES LN(/*number*/ + SQRT(/*number*/ * /*number*/ - 1));
  -- =ACOSH(2)
  VALUES LN(2e0 + SQRT(2e0 * 2 - 1));
  -- COL1: 1.316957896925e0

ACOT
^^^^

Returns the arccotangent of a number, in radians.

.. code-block:: sql

  -- =ACOT(number)
  VALUES PI() / 2 - ATAN(/*number*/);
  -- =ACOT(2)
  VALUES PI() / 2 - ATAN(2e0);
  -- COL1: 0.463647609001e0

ACOTH
^^^^^

Returns the inverse hyperbolic cotangent of a number.

.. code-block:: sql

  -- =ACOTH(number)
  VALUES 0.5e0 * LN((/*number*/ + 1) / (/*number*/ - 1));
  -- =ACOTH(2)
  VALUES 0.5e0 * LN((2e0 + 1) / (2e0 - 1));
  -- COL1: 0.549306144334e0

AGGREGATE
^^^^^^^^^

Applies a chosen aggregate, such as a sum or average, to a range while skipping
errors or hidden rows. Only in Excel.

.. code-block:: sql

  -- =AGGREGATE(9, 6, ref1)
  SELECT SUM(/*ref1*/) FROM /*table*/;
  -- =AGGREGATE(9, 6, C2:C5)
  SELECT SUM(price) FROM products;
  -- COL1: 8.75

Use the aggregate that ``function_num`` names (1 is AVG, 4 is MAX, 9 is SUM and
so on). NULLs are always skipped.

ARABIC
^^^^^^

.. code-block:: text

  =ARABIC(text)

Converts a Roman numeral to a number.

No equivalent.

ASIN
^^^^

Returns the arcsine of a number, in radians.

.. code-block:: sql

  -- =ASIN(number)
  VALUES ASIN(/*number*/);
  -- =ASIN(0.5)
  VALUES ASIN(0.5e0);
  -- COL1: 0.523598775598e0

ASINH
^^^^^

Returns the inverse hyperbolic sine of a number.

.. code-block:: sql

  -- =ASINH(number)
  VALUES LN(/*number*/ + SQRT(/*number*/ * /*number*/ + 1));
  -- =ASINH(2)
  VALUES LN(2e0 + SQRT(2e0 * 2 + 1));
  -- COL1: 1.443635475179e0

ATAN
^^^^

Returns the arctangent of a number, in radians.

.. code-block:: sql

  -- =ATAN(number)
  VALUES ATAN(/*number*/);
  -- =ATAN(1)
  VALUES ATAN(1e0);
  -- COL1: 0.785398163397e0

ATAN2
^^^^^

Returns the angle, in radians, of the point (x, y) from the x-axis.

.. code-block:: sql

  -- =ATAN2(x_num, y_num)
  VALUES ATAN2(/*y_num*/, /*x_num*/);
  -- =ATAN2(3, 4)
  VALUES ATAN2(4e0, 3e0);
  -- COL1: 0.927295218002e0

The arguments are the other way around: vsql takes y first, then x.

ATANH
^^^^^

Returns the inverse hyperbolic tangent of a number.

.. code-block:: sql

  -- =ATANH(number)
  VALUES 0.5e0 * LN((1 + /*number*/) / (1 - /*number*/));
  -- =ATANH(0.5)
  VALUES 0.5e0 * LN((1 + 0.5e0) / (1 - 0.5e0));
  -- COL1: 0.549306144334e0

BASE
^^^^

.. code-block:: text

  =BASE(number, radix, [min_length])

Converts a number to text in another base, such as binary or hexadecimal.

No equivalent.

CEILING.MATH
^^^^^^^^^^^^

Rounds a number up to the nearest multiple of a significance.

.. code-block:: sql

  -- =CEILING.MATH(number, significance)
  VALUES CEIL(/*number*/ / /*significance*/) * /*significance*/;
  -- =CEILING.MATH(17, 5)
  VALUES CEIL(17 / 5.0) * 5;
  -- COL1: 20

  -- =CEILING.MATH(number)
  VALUES CEIL(/*number*/);
  -- =CEILING.MATH(4.3)
  VALUES CEIL(4.3);
  -- COL1: 5

Negative numbers round towards zero, like the default ``mode``. For a nonzero
``mode``, round ``ABS`` of the number and put the sign back.

CEILING.PRECISE
^^^^^^^^^^^^^^^

Rounds a number up to the nearest multiple of a significance, whatever the sign
of the significance.

.. code-block:: sql

  -- =CEILING.PRECISE(number, significance)
  VALUES CEIL(/*number*/ / ABS(/*significance*/)) * ABS(/*significance*/);
  -- =CEILING.PRECISE(-4.3, 2)
  VALUES CEIL(-4.3 / ABS(2)) * ABS(2);
  -- COL1: -4

COMBIN
^^^^^^

Returns the number of ways to choose some items from a set, ignoring order.

.. code-block:: sql

  -- =COMBIN(number, number_chosen)
  VALUES FACTORIAL(/*number*/) / (FACTORIAL(/*number_chosen*/) * FACTORIAL(/*number*/ - /*number_chosen*/));
  -- =COMBIN(5, 2)
  VALUES FACTORIAL(5) / (FACTORIAL(2) * FACTORIAL(5 - 2));
  -- COL1: 10

COMBINA
^^^^^^^

Returns the number of ways to choose some items from a set, ignoring order and
allowing repeats.

.. code-block:: sql

  -- =COMBINA(number, number_chosen)
  VALUES FACTORIAL(/*number*/ + /*number_chosen*/ - 1) / (FACTORIAL(/*number_chosen*/) * FACTORIAL(/*number*/ - 1));
  -- =COMBINA(4, 3)
  VALUES FACTORIAL(4 + 3 - 1) / (FACTORIAL(3) * FACTORIAL(4 - 1));
  -- COL1: 20

This is COMBIN(number + number_chosen - 1, number_chosen).

COS
^^^

Returns the cosine of an angle in radians.

.. code-block:: sql

  -- =COS(number)
  VALUES COS(/*number*/);
  -- =COS(1)
  VALUES COS(1e0);
  -- COL1: 0.540302305868e0

COSH
^^^^

Returns the hyperbolic cosine of a number.

.. code-block:: sql

  -- =COSH(number)
  VALUES COSH(/*number*/);
  -- =COSH(1)
  VALUES COSH(1e0);
  -- COL1: 1.543080634815e0

COT
^^^

Returns the cotangent of an angle in radians.

.. code-block:: sql

  -- =COT(number)
  VALUES 1 / TAN(/*number*/);
  -- =COT(1)
  VALUES 1 / TAN(1e0);
  -- COL1: 0.642092615934e0

COTH
^^^^

Returns the hyperbolic cotangent of a number.

.. code-block:: sql

  -- =COTH(number)
  VALUES 1 / TANH(/*number*/);
  -- =COTH(1)
  VALUES 1 / TANH(1e0);
  -- COL1: 1.313035285499e0

CSC
^^^

Returns the cosecant of an angle in radians.

.. code-block:: sql

  -- =CSC(number)
  VALUES 1 / SIN(/*number*/);
  -- =CSC(1)
  VALUES 1 / SIN(1e0);
  -- COL1: 1.188395105778e0

CSCH
^^^^

Returns the hyperbolic cosecant of a number.

.. code-block:: sql

  -- =CSCH(number)
  VALUES 1 / SINH(/*number*/);
  -- =CSCH(1)
  VALUES 1 / SINH(1e0);
  -- COL1: 0.850918128239e0

DECIMAL
^^^^^^^

.. code-block:: text

  =DECIMAL(text, radix)

Converts text that holds a number in another base to a decimal number.

No equivalent.

DEGREES
^^^^^^^

Converts radians to degrees.

.. code-block:: sql

  -- =DEGREES(angle)
  VALUES DEGREES(/*angle*/);
  -- =DEGREES(PI())
  VALUES DEGREES(PI());
  -- COL1: 180e0

EVEN
^^^^

Rounds a number away from zero to the nearest even whole number.

.. code-block:: sql

  -- =EVEN(number)
  VALUES SIGN(/*number*/) * CEIL(ABS(/*number*/) / 2) * 2;
  -- =EVEN(3.2)
  VALUES SIGN(3.2) * CEIL(ABS(3.2) / 2) * 2;
  -- COL1: 4

EXP
^^^

Returns e raised to the power of a number.

.. code-block:: sql

  -- =EXP(number)
  VALUES EXP(/*number*/);
  -- =EXP(1)
  VALUES EXP(1e0);
  -- COL1: 2.718281828459e0

FACT
^^^^

Returns the factorial of a number.

.. code-block:: sql

  -- =FACT(number)
  VALUES FACTORIAL(/*number*/);
  -- =FACT(5)
  VALUES FACTORIAL(5);
  -- COL1: 120

The result is an exact NUMERIC, so a large factorial keeps every digit.

FACTDOUBLE
^^^^^^^^^^

.. code-block:: text

  =FACTDOUBLE(number)

Returns the double factorial of a number, the product of every second number
down to 1 or 2.

No equivalent.

FLOOR.MATH
^^^^^^^^^^

Rounds a number down to the nearest multiple of a significance.

.. code-block:: sql

  -- =FLOOR.MATH(number, significance)
  VALUES FLOOR(/*number*/ / /*significance*/) * /*significance*/;
  -- =FLOOR.MATH(17, 5)
  VALUES FLOOR(17 / 5.0) * 5;
  -- COL1: 15

  -- =FLOOR.MATH(number)
  VALUES FLOOR(/*number*/);
  -- =FLOOR.MATH(4.7)
  VALUES FLOOR(4.7);
  -- COL1: 4

Negative numbers round away from zero, like the default ``mode``. For a nonzero
``mode``, round ``ABS`` of the number and put the sign back.

FLOOR.PRECISE
^^^^^^^^^^^^^

Rounds a number down to the nearest multiple of a significance, whatever the
sign of the significance.

.. code-block:: sql

  -- =FLOOR.PRECISE(number, significance)
  VALUES FLOOR(/*number*/ / ABS(/*significance*/)) * ABS(/*significance*/);
  -- =FLOOR.PRECISE(-4.3, 2)
  VALUES FLOOR(-4.3 / ABS(2)) * ABS(2);
  -- COL1: -6

GCD
^^^

Returns the greatest common divisor of whole numbers.

.. code-block:: sql

  -- =GCD(number1, number2, ...)
  VALUES GCD(GCD(/*number1*/, /*number2*/), ...);
  -- =GCD(24, 36, 60)
  VALUES GCD(GCD(24, 36), 60);
  -- COL1: 12

GCD takes two numbers, so nest it for more.

INT
^^^

Rounds a number down to the nearest whole number.

.. code-block:: sql

  -- =INT(number)
  VALUES FLOOR(/*number*/);
  -- =INT(-4.3)
  VALUES FLOOR(-4.3);
  -- COL1: -5

ISO.CEILING
^^^^^^^^^^^

Rounds a number up to the nearest multiple of a significance, whatever the sign
of the significance.

.. code-block:: sql

  -- =ISO.CEILING(number, significance)
  VALUES CEIL(/*number*/ / ABS(/*significance*/)) * ABS(/*significance*/);
  -- =ISO.CEILING(-4.3, 2)
  VALUES CEIL(-4.3 / ABS(2)) * ABS(2);
  -- COL1: -4

LCM
^^^

Returns the least common multiple of whole numbers.

.. code-block:: sql

  -- =LCM(number1, number2, ...)
  VALUES LCM(LCM(/*number1*/, /*number2*/), ...);
  -- =LCM(4, 6, 10)
  VALUES LCM(LCM(4, 6), 10);
  -- COL1: 60

LCM takes two numbers, so nest it for more.

LN
^^

Returns the natural logarithm of a number.

.. code-block:: sql

  -- =LN(number)
  VALUES LN(/*number*/);
  -- =LN(10)
  VALUES LN(10e0);
  -- COL1: 2.302585092994e0

LOG
^^^

Returns the logarithm of a number in a base, which is 10 when left out.

.. code-block:: sql

  -- =LOG(number, base)
  VALUES LOG(/*base*/, /*number*/);
  -- =LOG(8, 2)
  VALUES LOG(2e0, 8e0);
  -- COL1: 3e0

  -- =LOG(number)
  VALUES LOG10(/*number*/);
  -- =LOG(100)
  VALUES LOG10(100e0);
  -- COL1: 2e0

The base comes first in vsql. Use ``LOG10(x)`` when there's no base.

LOG10
^^^^^

Returns the base-10 logarithm of a number.

.. code-block:: sql

  -- =LOG10(number)
  VALUES LOG10(/*number*/);
  -- =LOG10(1000)
  VALUES LOG10(1000e0);
  -- COL1: 3e0

MDETERM
^^^^^^^

.. code-block:: text

  =MDETERM(array)

Returns the determinant of a square matrix.

No equivalent.

MINVERSE
^^^^^^^^

.. code-block:: text

  =MINVERSE(array)

Returns the inverse of a square matrix.

No equivalent.

MMULT
^^^^^

.. code-block:: text

  =MMULT(array1, array2)

Returns the matrix product of two arrays.

No equivalent.

MOD
^^^

Returns the remainder after dividing a number by a divisor, with the sign of the
divisor.

.. code-block:: sql

  -- =MOD(number, divisor)
  VALUES MOD(MOD(/*number*/, /*divisor*/) + /*divisor*/, /*divisor*/);
  -- =MOD(-7, 3)
  VALUES MOD(MOD(-7, 3) + 3, 3);
  -- COL1: 2

On its own, ``MOD(-7, 3)`` is -1 in vsql, because its result takes the sign of
the number. When both are positive, plain ``MOD`` is enough.

MROUND
^^^^^^

Rounds a number to the nearest multiple of another number.

.. code-block:: sql

  -- =MROUND(number, multiple)
  VALUES ROUND(/*number*/ / /*multiple*/) * /*multiple*/;
  -- =MROUND(17, 5)
  VALUES ROUND(17 / 5.0) * 5;
  -- COL1: 15

MULTINOMIAL
^^^^^^^^^^^

Returns the factorial of a sum divided by the product of the factorials of its
parts.

.. code-block:: sql

  -- =MULTINOMIAL(number1, number2, ...)
  VALUES FACTORIAL(/*number1*/ + /*number2*/ + ...) / (FACTORIAL(/*number1*/) * FACTORIAL(/*number2*/) * ...);
  -- =MULTINOMIAL(2, 3, 4)
  VALUES FACTORIAL(2 + 3 + 4)
    / (FACTORIAL(2) * FACTORIAL(3) * FACTORIAL(4));
  -- COL1: 1260

MUNIT
^^^^^

.. code-block:: text

  =MUNIT(dimension)

Returns an identity matrix of a given size.

No equivalent.

ODD
^^^

Rounds a number away from zero to the nearest odd whole number.

.. code-block:: sql

  -- =ODD(number)
  VALUES SIGN(/*number*/) * (CEIL((ABS(/*number*/) + 1) / 2) * 2 - 1);
  -- =ODD(3.2)
  VALUES SIGN(3.2) * (CEIL((ABS(3.2) + 1) / 2) * 2 - 1);
  -- COL1: 5

``ODD(0)`` is 1 in a spreadsheet, but this gives 0.

PERCENTOF
^^^^^^^^^

Returns the sum of a subset as a fraction of the sum of all the data. Only in
Excel.

.. code-block:: sql

  -- =PERCENTOF(data_subset, data_all)
  SELECT SUM(/*data_all*/) FILTER (WHERE /*the rows of data_subset*/) / SUM(/*data_all*/) FROM /*table*/;
  -- =PERCENTOF(C2:C3, C2:C5)
  SELECT SUM(price) FILTER (WHERE sku IN ('A1', 'B2')) / SUM(price)
  FROM products;
  -- COL1: 0.2000

PI
^^

Returns the number pi.

.. code-block:: sql

  -- =PI()
  VALUES PI();
  -- =PI()
  VALUES PI();
  -- COL1: 3.14159265359e0

POWER
^^^^^

Raises a number to a power.

.. code-block:: sql

  -- =POWER(number, power)
  VALUES POWER(/*number*/, /*power*/);
  -- =POWER(2, 10)
  VALUES POWER(2, 10);
  -- COL1: 1024e0

PRODUCT
^^^^^^^

Multiplies numbers together.

.. code-block:: sql

  -- =PRODUCT(number1)
  SELECT PRODUCT(/*number1*/) FROM /*table*/ WHERE /*number1*/ IS NOT NULL;
  -- =PRODUCT(D2:D5)
  SELECT PRODUCT(qty) FROM products WHERE qty IS NOT NULL;
  -- COL1: 2000

QUOTIENT
^^^^^^^^

Returns the whole-number part of a division.

.. code-block:: sql

  -- =QUOTIENT(numerator, denominator)
  VALUES TRUNC(/*numerator*/ / /*denominator*/);
  -- =QUOTIENT(-7, 2)
  VALUES TRUNC(-7 / 2.0);
  -- COL1: -3

Dividing two integers already drops the remainder, so ``-7 / 2`` is -3 too.

RADIANS
^^^^^^^

Converts degrees to radians.

.. code-block:: sql

  -- =RADIANS(angle)
  VALUES RADIANS(/*angle*/);
  -- =RADIANS(180)
  VALUES RADIANS(180e0);
  -- COL1: 3.14159265359e0

RAND
^^^^

Returns a random number that is at least 0 and less than 1.

.. code-block:: sql

  -- =RAND()
  VALUES RANDOM();
  -- =RAND()
  VALUES RANDOM() < 1;
  -- COL1: TRUE

``RANDOM()`` gives a different number every time, so this example only checks
its range.

RANDARRAY
^^^^^^^^^

.. code-block:: text

  =RANDARRAY([rows], [columns], [min], [max], [whole_number])

Returns an array of random numbers.

No equivalent.

RANDBETWEEN
^^^^^^^^^^^

Returns a random whole number between two numbers, inclusive.

.. code-block:: sql

  -- =RANDBETWEEN(bottom, top)
  VALUES FLOOR(RANDOM() * (/*top*/ - /*bottom*/ + 1)) + /*bottom*/;
  -- =RANDBETWEEN(1, 6)
  VALUES FLOOR(RANDOM() * (6 - 1 + 1)) + 1 BETWEEN 1 AND 6;
  -- COL1: TRUE

The random number is ``FLOOR(RANDOM() * (6 - 1 + 1)) + 1``; this example only
checks its range.

ROMAN
^^^^^

.. code-block:: text

  =ROMAN(number, [form])

Converts a number to a Roman numeral.

No equivalent.

ROUND
^^^^^

Rounds a number to a number of decimal places, with halves away from zero.

.. code-block:: sql

  -- =ROUND(number, num_digits)
  VALUES ROUND(/*number*/, /*num_digits*/);
  -- =ROUND(2.345, 2)
  VALUES ROUND(2.345, 2);
  -- COL1: 2.35

ROUNDDOWN
^^^^^^^^^

Rounds a number towards zero to a number of decimal places.

.. code-block:: sql

  -- =ROUNDDOWN(number, num_digits)
  VALUES TRUNC(/*number*/, /*num_digits*/);
  -- =ROUNDDOWN(2.789, 1)
  VALUES TRUNC(2.789, 1);
  -- COL1: 2.7

ROUNDUP
^^^^^^^

Rounds a number away from zero to a number of decimal places.

.. code-block:: sql

  -- =ROUNDUP(number, num_digits)
  VALUES SIGN(/*number*/) * CEIL(ABS(/*number*/) * /*10 to the power of num_digits*/) / /*10 to the power of num_digits*/;
  -- =ROUNDUP(2.341, 1)
  VALUES SIGN(2.341) * CEIL(ABS(2.341) * 10) / 10.0;
  -- COL1: 2.4

The 10 is ``POWER(10, num_digits)``.

SEC
^^^

Returns the secant of an angle in radians.

.. code-block:: sql

  -- =SEC(number)
  VALUES 1 / COS(/*number*/);
  -- =SEC(1)
  VALUES 1 / COS(1e0);
  -- COL1: 1.850815717681e0

SECH
^^^^

Returns the hyperbolic secant of a number.

.. code-block:: sql

  -- =SECH(number)
  VALUES 1 / COSH(/*number*/);
  -- =SECH(1)
  VALUES 1 / COSH(1e0);
  -- COL1: 0.648054273664e0

SEQUENCE
^^^^^^^^

.. code-block:: text

  =SEQUENCE(rows, [columns], [start], [step])

Returns an array of numbers counting up in steps.

No equivalent.

SERIESSUM
^^^^^^^^^

Returns the sum of a power series.

.. code-block:: sql

  -- =SERIESSUM(x, n, m, coefficients)
  SELECT SUM(/*coefficients*/ * POWER(/*x*/, /*n*/ + (/*position of the coefficient*/ - 1) * /*m*/)) FROM /*table*/;
  -- =SERIESSUM(2, 0, 1, {1, 2, 3})
  SELECT SUM(a * POWER(2, 0 + (i - 1) * 1))
  FROM (VALUES (1, 1), (2, 2), (3, 3)) AS c (i, a);
  -- COL1: 17e0

Each coefficient needs its position ``i``, counting from 1.

SIGN
^^^^

Returns 1 for a positive number, -1 for a negative number and 0 for zero.

.. code-block:: sql

  -- =SIGN(number)
  VALUES SIGN(/*number*/);
  -- =SIGN(-3)
  VALUES SIGN(-3);
  -- COL1: -1

SIN
^^^

Returns the sine of an angle in radians.

.. code-block:: sql

  -- =SIN(number)
  VALUES SIN(/*number*/);
  -- =SIN(1)
  VALUES SIN(1e0);
  -- COL1: 0.841470984808e0

SINH
^^^^

Returns the hyperbolic sine of a number.

.. code-block:: sql

  -- =SINH(number)
  VALUES SINH(/*number*/);
  -- =SINH(1)
  VALUES SINH(1e0);
  -- COL1: 1.175201193644e0

SQRT
^^^^

Returns the square root of a number.

.. code-block:: sql

  -- =SQRT(number)
  VALUES SQRT(/*number*/);
  -- =SQRT(16)
  VALUES SQRT(16e0);
  -- COL1: 4e0

SQRTPI
^^^^^^

Returns the square root of a number multiplied by pi.

.. code-block:: sql

  -- =SQRTPI(number)
  VALUES SQRT(/*number*/ * PI());
  -- =SQRTPI(2)
  VALUES SQRT(2 * PI());
  -- COL1: 2.506628274631e0

SUBTOTAL
^^^^^^^^

Applies a chosen aggregate, such as a sum or average, to a range, ignoring other
subtotals.

.. code-block:: sql

  -- =SUBTOTAL(1, ref1)
  SELECT AVG(/*ref1*/) FROM /*table*/;
  -- =SUBTOTAL(1, B2:B5)
  SELECT AVG(y) FROM points;
  -- COL1: 5.05e0

Use the aggregate that ``function_num`` names (1 is AVG, 4 is MAX, 9 is SUM and
so on). Add ``GROUP BY`` for one subtotal per group.

SUM
^^^

Adds numbers.

.. code-block:: sql

  -- =SUM(number1)
  SELECT SUM(/*number1*/) FROM /*table*/;
  -- =SUM(C2:C5)
  SELECT SUM(price) FROM products;
  -- COL1: 8.75

  -- =SUM(number1, number2, ...)
  VALUES /*number1*/ + /*number2*/ + ...;
  -- =SUM(1, 2, 3)
  VALUES 1 + 2 + 3;
  -- COL1: 6

SUMIF
^^^^^

Adds the values that meet one condition.

.. code-block:: sql

  -- =SUMIF(range, criteria, sum_range)
  SELECT SUM(/*sum_range*/) FILTER (WHERE /*range*/ /*criteria*/) FROM /*table*/;
  -- =SUMIF(C2:C5, "<2", D2:D5)
  SELECT SUM(qty) FILTER (WHERE price < 2) FROM products;
  -- COL1: 50

  -- =SUMIF(range, criteria)
  SELECT SUM(/*range*/) FILTER (WHERE /*range*/ /*criteria*/) FROM /*table*/;
  -- =SUMIF(C2:C5, "<2")
  SELECT SUM(price) FILTER (WHERE price < 2) FROM products;
  -- COL1: 1.75

SUMIFS
^^^^^^

Adds the values that meet several conditions.

.. code-block:: sql

  -- =SUMIFS(sum_range, criteria_range1, criteria1, criteria_range2, criteria2, ...)
  SELECT SUM(/*sum_range*/) FILTER (WHERE /*criteria_range1*/ /*criteria1*/ AND /*criteria_range2*/ /*criteria2*/ ...) FROM /*table*/;
  -- =SUMIFS(D2:D5, C2:C5, "<2", B2:B5, "B*")
  SELECT SUM(qty) FILTER (WHERE price < 2 AND name LIKE 'B%') FROM products;
  -- COL1: 40

SUMPRODUCT
^^^^^^^^^^

Multiplies matching values in ranges and adds the products.

.. code-block:: sql

  -- =SUMPRODUCT(array1, array2)
  SELECT SUM(/*array1*/ * /*array2*/) FROM /*table*/;
  -- =SUMPRODUCT(A2:A5, B2:B5)
  SELECT SUM(x * y) FROM points;
  -- COL1: 60.7e0

SUMSQ
^^^^^

Adds the squares of numbers.

.. code-block:: sql

  -- =SUMSQ(number1)
  SELECT SUM(/*number1*/ * /*number1*/) FROM /*table*/;
  -- =SUMSQ(A2:A5)
  SELECT SUM(x * x) FROM points;
  -- COL1: 30e0

SUMX2MY2
^^^^^^^^

Adds the differences of the squares of matching values in two ranges.

.. code-block:: sql

  -- =SUMX2MY2(array_x, array_y)
  SELECT SUM(/*array_x*/ * /*array_x*/ - /*array_y*/ * /*array_y*/) FROM /*table*/;
  -- =SUMX2MY2(A2:A5, B2:B5)
  SELECT SUM(x * x - y * y) FROM points;
  -- COL1: -92.86e0

SUMX2PY2
^^^^^^^^

Adds the sums of the squares of matching values in two ranges.

.. code-block:: sql

  -- =SUMX2PY2(array_x, array_y)
  SELECT SUM(/*array_x*/ * /*array_x*/ + /*array_y*/ * /*array_y*/) FROM /*table*/;
  -- =SUMX2PY2(A2:A5, B2:B5)
  SELECT SUM(x * x + y * y) FROM points;
  -- COL1: 152.86e0

SUMXMY2
^^^^^^^

Adds the squares of the differences of matching values in two ranges.

.. code-block:: sql

  -- =SUMXMY2(array_x, array_y)
  SELECT SUM((/*array_x*/ - /*array_y*/) * (/*array_x*/ - /*array_y*/)) FROM /*table*/;
  -- =SUMXMY2(A2:A5, B2:B5)
  SELECT SUM((x - y) * (x - y)) FROM points;
  -- COL1: 31.46e0

TAN
^^^

Returns the tangent of an angle in radians.

.. code-block:: sql

  -- =TAN(number)
  VALUES TAN(/*number*/);
  -- =TAN(1)
  VALUES TAN(1e0);
  -- COL1: 1.557407724655e0

TANH
^^^^

Returns the hyperbolic tangent of a number.

.. code-block:: sql

  -- =TANH(number)
  VALUES TANH(/*number*/);
  -- =TANH(1)
  VALUES TANH(1e0);
  -- COL1: 0.761594155956e0

TRUNC
^^^^^

Cuts a number towards zero to a number of decimal places, which is 0 when left
out.

.. code-block:: sql

  -- =TRUNC(number, num_digits)
  VALUES TRUNC(/*number*/, /*num_digits*/);
  -- =TRUNC(-4.37, 1)
  VALUES TRUNC(-4.37, 1);
  -- COL1: -4.3

  -- =TRUNC(number)
  VALUES TRUNC(/*number*/);
  -- =TRUNC(-4.37)
  VALUES TRUNC(-4.37);
  -- COL1: -4

Operator
--------

ADD
^^^

Returns the sum of two numbers. Only in Google Sheets.

.. code-block:: sql

  -- =ADD(value1, value2)
  VALUES /*value1*/ + /*value2*/;
  -- =ADD(2, 3)
  VALUES 2 + 3;
  -- COL1: 5

DIVIDE
^^^^^^

Returns one number divided by another. Only in Google Sheets.

.. code-block:: sql

  -- =DIVIDE(dividend, divisor)
  VALUES /*dividend*/ / /*divisor*/;
  -- =DIVIDE(10, 4)
  VALUES 10 / 4.0;
  -- COL1: 2.5

Dividing two integers truncates (10 / 4 is 2), and a decimal result keeps the decimal places of its operands (1 / 3.0 is 0.3). Use 1 / 3e0 for full precision.

EQ
^^

Returns TRUE if two values are equal. Only in Google Sheets.

.. code-block:: sql

  -- =EQ(value1, value2)
  VALUES /*value1*/ = /*value2*/;
  -- =EQ(2, 2)
  VALUES 2 = 2;
  -- COL1: TRUE

Text comparison is case-sensitive, where EQ ignores case.

GT
^^

Returns TRUE if the first value is greater than the second. Only in Google Sheets.

.. code-block:: sql

  -- =GT(value1, value2)
  VALUES /*value1*/ > /*value2*/;
  -- =GT(3, 2)
  VALUES 3 > 2;
  -- COL1: TRUE

GTE
^^^

Returns TRUE if the first value is greater than or equal to the second. Only in Google Sheets.

.. code-block:: sql

  -- =GTE(value1, value2)
  VALUES /*value1*/ >= /*value2*/;
  -- =GTE(2, 2)
  VALUES 2 >= 2;
  -- COL1: TRUE

ISBETWEEN
^^^^^^^^^

Returns TRUE if a value lies between two others. Only in Google Sheets.

.. code-block:: sql

  -- =ISBETWEEN(value_to_compare, lower_value, upper_value)
  VALUES /*value_to_compare*/ BETWEEN /*lower_value*/ AND /*upper_value*/;
  -- =ISBETWEEN(5, 1, 10)
  VALUES 5 BETWEEN 1 AND 10;
  -- COL1: TRUE

  -- =ISBETWEEN(value_to_compare, lower_value, upper_value, FALSE, FALSE)
  VALUES /*value_to_compare*/ > /*lower_value*/ AND /*value_to_compare*/ < /*upper_value*/;
  -- =ISBETWEEN(10, 1, 10, FALSE, FALSE)
  VALUES 10 > 1 AND 10 < 10;
  -- COL1: FALSE

BETWEEN includes both ends; for exclusive ends write 5 > 1 AND 5 < 10.

LT
^^

Returns TRUE if the first value is less than the second. Only in Google Sheets.

.. code-block:: sql

  -- =LT(value1, value2)
  VALUES /*value1*/ < /*value2*/;
  -- =LT(2, 3)
  VALUES 2 < 3;
  -- COL1: TRUE

LTE
^^^

Returns TRUE if the first value is less than or equal to the second. Only in Google Sheets.

.. code-block:: sql

  -- =LTE(value1, value2)
  VALUES /*value1*/ <= /*value2*/;
  -- =LTE(3, 2)
  VALUES 3 <= 2;
  -- COL1: FALSE

MINUS
^^^^^

Returns the difference of two numbers. Only in Google Sheets.

.. code-block:: sql

  -- =MINUS(value1, value2)
  VALUES /*value1*/ - /*value2*/;
  -- =MINUS(5, 3)
  VALUES 5 - 3;
  -- COL1: 2

MULTIPLY
^^^^^^^^

Returns the product of two numbers. Only in Google Sheets.

.. code-block:: sql

  -- =MULTIPLY(factor1, factor2)
  VALUES /*factor1*/ * /*factor2*/;
  -- =MULTIPLY(4, 2.5)
  VALUES 4 * 2.5;
  -- COL1: 10.0

NE
^^

Returns TRUE if two values are not equal. Only in Google Sheets.

.. code-block:: sql

  -- =NE(value1, value2)
  VALUES /*value1*/ <> /*value2*/;
  -- =NE(2, 3)
  VALUES 2 <> 3;
  -- COL1: TRUE

POW
^^^

Returns a number raised to a power. Only in Google Sheets.

.. code-block:: sql

  -- =POW(base, exponent)
  VALUES POWER(/*base*/, /*exponent*/);
  -- =POW(2, 10)
  VALUES POWER(2, 10);
  -- COL1: 1024e0

UMINUS
^^^^^^

Returns a number with its sign flipped. Only in Google Sheets.

.. code-block:: sql

  -- =UMINUS(value)
  VALUES -/*value*/;
  -- =UMINUS(5)
  VALUES -5;
  -- COL1: -5

UNARY_PERCENT
^^^^^^^^^^^^^

Returns a number divided by 100. Only in Google Sheets.

.. code-block:: sql

  -- =UNARY_PERCENT(percentage)
  VALUES /*percentage*/ * 0.01;
  -- =UNARY_PERCENT(25)
  VALUES 25 * 0.01;
  -- COL1: 0.25

UPLUS
^^^^^

Returns a number unchanged. Only in Google Sheets.

.. code-block:: sql

  -- =UPLUS(value)
  VALUES +/*value*/;
  -- =UPLUS(5)
  VALUES +5;
  -- COL1: 5

Parser
------

TO_DATE
^^^^^^^

.. code-block:: text

  =TO_DATE(value)

Converts a number to a date. Only in Google Sheets.

No equivalent.

TO_DOLLARS
^^^^^^^^^^

Formats a number as a dollar amount. Only in Google Sheets.

.. code-block:: sql

  -- =TO_DOLLARS(value)
  VALUES '$' || CAST(CAST(/*value*/ AS DECIMAL(10, 2)) AS VARCHAR(20));
  -- =TO_DOLLARS(1.5)
  VALUES '$' || CAST(CAST(1.5 AS DECIMAL(10, 2)) AS VARCHAR(20));
  -- COL1: $1.50

The result is text, and there are no thousands separators.

TO_PERCENT
^^^^^^^^^^

Formats a number as a percentage. Only in Google Sheets.

.. code-block:: sql

  -- =TO_PERCENT(value)
  VALUES CAST(CAST(/*value*/ * 100 AS DECIMAL(10, 0)) AS VARCHAR(20)) || '%';
  -- =TO_PERCENT(0.25)
  VALUES CAST(CAST(0.25 * 100 AS DECIMAL(10, 0)) AS VARCHAR(20)) || '%';
  -- COL1: 25%

The result is text, not a number.

TO_PURE_NUMBER
^^^^^^^^^^^^^^

Returns a value as a plain number without its formatting. Only in Google Sheets.

.. code-block:: sql

  -- =TO_PURE_NUMBER(value)
  VALUES /*the number that value is formatted from*/;
  -- =TO_PURE_NUMBER(TO_PERCENT(0.25))
  VALUES 0.25;
  -- COL1: 0.25

Numbers carry no display format, so there is nothing to remove.

TO_TEXT
^^^^^^^

Converts a number to text. Only in Google Sheets.

.. code-block:: sql

  -- =TO_TEXT(value)
  VALUES CAST(/*value*/ AS VARCHAR(20));
  -- =TO_TEXT(24)
  VALUES CAST(24 AS VARCHAR(20));
  -- COL1: 24

Statistical
-----------

AVEDEV
^^^^^^

Returns the average of the absolute distances of values from their mean.

.. code-block:: sql

  -- =AVEDEV(number1)
  SELECT AVG(ABS(/*number1*/ - a)) FROM /*table*/, (SELECT AVG(/*number1*/) AS a FROM /*table*/) AS m;
  -- =AVEDEV(B2:B5)
  SELECT AVG(ABS(y - a))
  FROM points, (SELECT AVG(y) AS a FROM points) AS m;
  -- COL1: 2e0

AVERAGE
^^^^^^^

Returns the arithmetic mean.

.. code-block:: sql

  -- =AVERAGE(number1)
  SELECT AVG(CAST(/*number1*/ AS DOUBLE PRECISION)) FROM /*table*/;
  -- =AVERAGE(C2:C5)
  SELECT AVG(CAST(price AS DOUBLE PRECISION)) FROM products;
  -- COL1: 2.1875e0

AVG of a DECIMAL or INTEGER column keeps that type, so AVG(price) is 2.18; cast it to keep every digit.

AVERAGE.WEIGHTED
^^^^^^^^^^^^^^^^

Returns a mean in which each value has a weight. Only in Google Sheets.

.. code-block:: sql

  -- =AVERAGE.WEIGHTED(values, weights)
  SELECT SUM(/*values*/ * /*weights*/) * 1e0 / SUM(/*weights*/) FROM /*table*/ WHERE /*weights*/ IS NOT NULL;
  -- =AVERAGE.WEIGHTED(C2:C4, D2:D4)
  SELECT SUM(price * qty) * 1e0 / SUM(qty) FROM products
  WHERE qty IS NOT NULL;
  -- COL1: 0.818181818182e0

AVERAGEA
^^^^^^^^

Returns the mean, counting text as 0 and logical values as 0 or 1.

.. code-block:: sql

  -- =AVERAGEA(value1)
  SELECT AVG(CAST(COALESCE(/*value1*/, 0) AS DOUBLE PRECISION)) FROM /*table*/;
  -- =AVERAGEA(D2:D5)
  SELECT AVG(CAST(COALESCE(qty, 0) AS DOUBLE PRECISION))
  FROM products;
  -- COL1: 13.75e0

A column holds only one type, so the nearest match to text counting as 0 is a NULL counting as 0; for truly empty cells, which are skipped, use AVERAGE.

AVERAGEIF
^^^^^^^^^

Returns the mean of the values that meet a condition.

.. code-block:: sql

  -- =AVERAGEIF(range, criteria, average_range)
  SELECT AVG(/*average_range*/) FILTER (WHERE /*range*/ /*criteria*/) FROM /*table*/;
  -- =AVERAGEIF(A2:A5, ">2", B2:B5)
  SELECT AVG(y) FILTER (WHERE x > 2) FROM points;
  -- COL1: 7.05e0

AVERAGEIFS
^^^^^^^^^^

Returns the mean of the values that meet several conditions.

.. code-block:: sql

  -- =AVERAGEIFS(average_range, criteria_range1, criteria1, criteria_range2, criteria2, ...)
  SELECT AVG(/*average_range*/) FILTER (WHERE /*criteria_range1*/ /*criteria1*/ AND /*criteria_range2*/ /*criteria2*/ ...) FROM /*table*/;
  -- =AVERAGEIFS(B2:B5, A2:A5, ">1", A2:A5, "<4")
  SELECT AVG(y) FILTER (WHERE x > 1 AND x < 4) FROM points;
  -- COL1: 5e0

BETA.DIST
^^^^^^^^^

.. code-block:: text

  =BETA.DIST(x, alpha, beta, cumulative, [a], [b])

Returns the beta distribution.

No equivalent.

BETA.INV
^^^^^^^^

.. code-block:: text

  =BETA.INV(probability, alpha, beta, [a], [b])

Returns the value at which the cumulative beta distribution reaches a probability.

No equivalent.

BINOM.DIST
^^^^^^^^^^

Returns the binomial probability of a number of successes in a number of trials.

.. code-block:: sql

  -- =BINOM.DIST(number_s, trials, probability_s, FALSE)
  VALUES FACTORIAL(/*trials*/) / (FACTORIAL(/*number_s*/) * FACTORIAL(/*trials*/ - /*number_s*/))
    * POWER(/*probability_s*/, /*number_s*/) * POWER(1 - /*probability_s*/, /*trials*/ - /*number_s*/);
  -- =BINOM.DIST(2, 5, 0.5, FALSE)
  VALUES FACTORIAL(5) / (FACTORIAL(2) * FACTORIAL(5 - 2))
    * POWER(0.5e0, 2) * POWER(1 - 0.5e0, 5 - 2);
  -- COL1: 0.3125e0

The binomial coefficient COMBIN(trials, number_s) is written with FACTORIAL. For cumulative TRUE, add up the terms for 0 to number_s.

BINOM.DIST.RANGE
^^^^^^^^^^^^^^^^

Returns the binomial probability that the number of successes falls in a range.

.. code-block:: sql

  -- =BINOM.DIST.RANGE(trials, probability_s, number_s, number_s2)
  SELECT SUM(FACTORIAL(/*trials*/) / (FACTORIAL(k) * FACTORIAL(/*trials*/ - k))
    * POWER(/*probability_s*/, k) * POWER(1 - /*probability_s*/, /*trials*/ - k))
  FROM (VALUES /*number_s*/, ..., /*number_s2*/) AS t (k);
  -- =BINOM.DIST.RANGE(3, 0.5, 1, 2)
  SELECT SUM(FACTORIAL(3) / (FACTORIAL(k) * FACTORIAL(3 - k))
    * POWER(0.5e0, k) * POWER(1 - 0.5e0, 3 - k))
  FROM (VALUES 1, 2) AS t (k);
  -- COL1: 0.75e0

Each row is a number of successes k, and COMBIN(3, k) is written with FACTORIAL.

BINOM.INV
^^^^^^^^^

.. code-block:: text

  =BINOM.INV(trials, probability_s, alpha)

Returns the smallest number of successes whose cumulative binomial probability reaches a criterion.

No equivalent.

CHISQ.DIST
^^^^^^^^^^

.. code-block:: text

  =CHISQ.DIST(x, deg_freedom, cumulative)

Returns the left-tailed chi-squared distribution.

No equivalent.

CHISQ.DIST.RT
^^^^^^^^^^^^^

.. code-block:: text

  =CHISQ.DIST.RT(x, deg_freedom)

Returns the right-tailed probability of the chi-squared distribution.

No equivalent.

CHISQ.INV
^^^^^^^^^

.. code-block:: text

  =CHISQ.INV(probability, deg_freedom)

Returns the inverse of the left-tailed chi-squared distribution.

No equivalent.

CHISQ.INV.RT
^^^^^^^^^^^^

.. code-block:: text

  =CHISQ.INV.RT(probability, deg_freedom)

Returns the inverse of the right-tailed chi-squared distribution.

No equivalent.

CHISQ.TEST
^^^^^^^^^^

.. code-block:: text

  =CHISQ.TEST(actual_range, expected_range)

Returns the p-value of a chi-squared test of independence.

No equivalent.

CONFIDENCE.NORM
^^^^^^^^^^^^^^^

.. code-block:: text

  =CONFIDENCE.NORM(alpha, standard_dev, size)

Returns the half-width of a confidence interval for a mean, using the normal distribution.

No equivalent.

CONFIDENCE.T
^^^^^^^^^^^^

.. code-block:: text

  =CONFIDENCE.T(alpha, standard_dev, size)

Returns the half-width of a confidence interval for a mean, using Student's t-distribution.

No equivalent.

CORREL
^^^^^^

Returns the correlation coefficient of two sets of values.

.. code-block:: sql

  -- =CORREL(array1, array2)
  SELECT CORR(/*array1*/, /*array2*/) FROM /*table*/;
  -- =CORREL(B2:B5, A2:A5)
  SELECT CORR(y, x) FROM points;
  -- COL1: 0.998992298024e0

COUNT
^^^^^

Counts the cells that contain numbers.

.. code-block:: sql

  -- =COUNT(value1)
  SELECT COUNT(/*value1*/) FROM /*table*/;
  -- =COUNT(C2:C5)
  SELECT COUNT(price) FROM products;
  -- COL1: 4

COUNT counts every non-NULL value, whatever its type; a column holds only one type, so it matches when the column is numeric.

COUNTA
^^^^^^

Counts the cells that are not empty.

.. code-block:: sql

  -- =COUNTA(value1)
  SELECT COUNT(/*value1*/) FROM /*table*/;
  -- =COUNTA(A2:A5)
  SELECT COUNT(sku) FROM products;
  -- COL1: 4

COUNTBLANK
^^^^^^^^^^

Counts the empty cells in a range.

.. code-block:: sql

  -- =COUNTBLANK(range)
  SELECT COUNT(*) FILTER (WHERE /*range*/ IS NULL) FROM /*table*/;
  -- =COUNTBLANK(D2:D5)
  SELECT COUNT(*) FILTER (WHERE qty IS NULL) FROM products;
  -- COL1: 1

The spreadsheet also counts cells holding an empty string; for text, add OR x = ''.

COUNTIF
^^^^^^^

Counts the cells that meet a condition.

.. code-block:: sql

  -- =COUNTIF(range, criteria)
  SELECT COUNT(*) FILTER (WHERE /*range*/ /*criteria*/) FROM /*table*/;
  -- =COUNTIF(C2:C5, ">2")
  SELECT COUNT(*) FILTER (WHERE price > 2) FROM products;
  -- COL1: 2

COUNTIFS
^^^^^^^^

Counts the rows that meet several conditions.

.. code-block:: sql

  -- =COUNTIFS(criteria_range1, criteria1, criteria_range2, criteria2, ...)
  SELECT COUNT(*) FILTER (WHERE /*criteria_range1*/ /*criteria1*/ AND /*criteria_range2*/ /*criteria2*/ ...) FROM /*table*/;
  -- =COUNTIFS(C2:C5, ">1", D2:D5, ">=10")
  SELECT COUNT(*) FILTER (WHERE price > 1 AND qty >= 10)
  FROM products;
  -- COL1: 1

COUNTUNIQUE
^^^^^^^^^^^

Counts the distinct values. Only in Google Sheets.

.. code-block:: sql

  -- =COUNTUNIQUE(value1)
  SELECT COUNT(DISTINCT /*value1*/) FROM /*table*/;
  -- =COUNTUNIQUE(1, 2, 2, 3)
  SELECT COUNT(DISTINCT v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
  -- COL1: 3

COUNTUNIQUEIFS
^^^^^^^^^^^^^^

Counts the distinct values in the rows that meet conditions. Only in Google Sheets.

.. code-block:: sql

  -- =COUNTUNIQUEIFS(range, criteria_range1, criterion1)
  SELECT COUNT(DISTINCT /*range*/) FILTER (WHERE /*criteria_range1*/ /*criterion1*/) FROM /*table*/;
  -- =COUNTUNIQUEIFS(B2:B5, C2:C5, ">1")
  SELECT COUNT(DISTINCT name) FILTER (WHERE price > 1)
  FROM products;
  -- COL1: 3

COVARIANCE.P
^^^^^^^^^^^^

Returns the population covariance of two sets of values.

.. code-block:: sql

  -- =COVARIANCE.P(array1, array2)
  SELECT COVAR_POP(/*array1*/, /*array2*/) FROM /*table*/;
  -- =COVARIANCE.P(B2:B5, A2:A5)
  SELECT COVAR_POP(y, x) FROM points;
  -- COL1: 2.55e0

COVARIANCE.S
^^^^^^^^^^^^

Returns the sample covariance of two sets of values.

.. code-block:: sql

  -- =COVARIANCE.S(array1, array2)
  SELECT COVAR_SAMP(/*array1*/, /*array2*/) FROM /*table*/;
  -- =COVARIANCE.S(B2:B5, A2:A5)
  SELECT COVAR_SAMP(y, x) FROM points;
  -- COL1: 3.4e0

DEVSQ
^^^^^

Returns the sum of the squared distances of values from their mean.

.. code-block:: sql

  -- =DEVSQ(number1)
  SELECT VAR_POP(/*number1*/) * COUNT(/*number1*/) FROM /*table*/;
  -- =DEVSQ(B2:B5)
  SELECT VAR_POP(y) * COUNT(y) FROM points;
  -- COL1: 20.85e0

EXPON.DIST
^^^^^^^^^^

Returns the exponential distribution.

.. code-block:: sql

  -- =EXPON.DIST(x, lambda, TRUE)
  VALUES 1 - EXP(-/*lambda*/ * /*x*/);
  -- =EXPON.DIST(0.5, 2, TRUE)
  VALUES 1 - EXP(-2 * 0.5e0);
  -- COL1: 0.632120558829e0

  -- =EXPON.DIST(x, lambda, FALSE)
  VALUES /*lambda*/ * EXP(-/*lambda*/ * /*x*/);
  -- =EXPON.DIST(0.5, 2, FALSE)
  VALUES 2 * EXP(-2 * 0.5e0);
  -- COL1: 0.735758882343e0

For cumulative FALSE, use 2 * EXP(-2 * 0.5e0).

F.DIST
^^^^^^

.. code-block:: text

  =F.DIST(x, deg_freedom1, deg_freedom2, cumulative)

Returns the F probability distribution.

No equivalent.

F.DIST.RT
^^^^^^^^^

.. code-block:: text

  =F.DIST.RT(x, deg_freedom1, deg_freedom2)

Returns the right-tailed F probability distribution.

No equivalent.

F.INV
^^^^^

.. code-block:: text

  =F.INV(probability, deg_freedom1, deg_freedom2)

Returns the inverse of the F probability distribution.

No equivalent.

F.INV.RT
^^^^^^^^

.. code-block:: text

  =F.INV.RT(probability, deg_freedom1, deg_freedom2)

Returns the inverse of the right-tailed F probability distribution.

No equivalent.

F.TEST
^^^^^^

.. code-block:: text

  =F.TEST(array1, array2)

Returns the p-value of an F-test on the variances of two sets of values.

No equivalent.

FISHER
^^^^^^

Returns the Fisher transformation of a correlation.

.. code-block:: sql

  -- =FISHER(x)
  VALUES 0.5 * LN((1 + /*x*/) / (1 - /*x*/));
  -- =FISHER(0.75)
  VALUES 0.5 * LN((1 + 0.75e0) / (1 - 0.75e0));
  -- COL1: 0.972955074528e0

FISHERINV
^^^^^^^^^

Returns the inverse of the Fisher transformation.

.. code-block:: sql

  -- =FISHERINV(y)
  VALUES TANH(/*y*/);
  -- =FISHERINV(0.5)
  VALUES TANH(0.5e0);
  -- COL1: 0.46211715726e0

FORECAST.ETS
^^^^^^^^^^^^

.. code-block:: text

  =FORECAST.ETS(target_date, values, timeline, [seasonality], [data_completion], [aggregation])

Predicts a future value with exponential smoothing. Only in Excel.

No equivalent.

FORECAST.ETS.CONFINT
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  =FORECAST.ETS.CONFINT(target_date, values, timeline, [confidence_level], [seasonality], [data_completion], [aggregation])

Returns the confidence interval of an exponential smoothing forecast. Only in Excel.

No equivalent.

FORECAST.ETS.SEASONALITY
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  =FORECAST.ETS.SEASONALITY(values, timeline, [data_completion], [aggregation])

Returns the length of the repeating pattern found in a time series. Only in Excel.

No equivalent.

FORECAST.ETS.STAT
^^^^^^^^^^^^^^^^^

.. code-block:: text

  =FORECAST.ETS.STAT(values, timeline, statistic_type, [seasonality], [data_completion], [aggregation])

Returns a statistic of an exponential smoothing forecast. Only in Excel.

No equivalent.

FORECAST.LINEAR
^^^^^^^^^^^^^^^

Predicts a value on the straight line fitted to known values.

.. code-block:: sql

  -- =FORECAST.LINEAR(x, known_ys, known_xs)
  SELECT REGR_INTERCEPT(/*known_ys*/, /*known_xs*/) + REGR_SLOPE(/*known_ys*/, /*known_xs*/) * /*x*/ FROM /*table*/;
  -- =FORECAST.LINEAR(5, B2:B5, A2:A5)
  SELECT REGR_INTERCEPT(y, x) + REGR_SLOPE(y, x) * 5 FROM points;
  -- COL1: 10.15e0

FREQUENCY
^^^^^^^^^

Counts how many values fall into each bin.

.. code-block:: sql

  -- =FREQUENCY(data_array, bins_array)
  SELECT COUNT(*) FILTER (WHERE /*data_array*/ <= /*first bin*/),
         COUNT(*) FILTER (WHERE /*data_array*/ > /*first bin*/ AND /*data_array*/ <= /*second bin*/), ...,
         COUNT(*) FILTER (WHERE /*data_array*/ > /*last bin*/)
  FROM /*table*/;
  -- =FREQUENCY(C2:C5, {1; 3})
  SELECT COUNT(*) FILTER (WHERE price <= 1) AS bin1,
         COUNT(*) FILTER (WHERE price > 1 AND price <= 3) AS bin2,
         COUNT(*) FILTER (WHERE price > 3) AS bin3
  FROM products;
  -- BIN1: 1 BIN2: 2 BIN3: 1

The counts come back as columns of one row, where the spreadsheet returns them down a column.

GAMMA
^^^^^

Returns the gamma function of a number.

.. code-block:: sql

  -- =GAMMA(number)
  VALUES GAMMA(/*number*/);
  -- =GAMMA(2.5)
  VALUES GAMMA(2.5);
  -- COL1: 1.329340388179e0

GAMMA.DIST
^^^^^^^^^^

.. code-block:: text

  =GAMMA.DIST(x, alpha, beta, cumulative)

Returns the gamma distribution.

No equivalent.

GAMMA.INV
^^^^^^^^^

.. code-block:: text

  =GAMMA.INV(probability, alpha, beta)

Returns the inverse of the cumulative gamma distribution.

No equivalent.

GAMMALN
^^^^^^^

Returns the natural logarithm of the gamma function.

.. code-block:: sql

  -- =GAMMALN(x)
  VALUES LGAMMA(/*x*/);
  -- =GAMMALN(10)
  VALUES LGAMMA(10);
  -- COL1: 12.801827480081e0

The spreadsheet returns #NUM! for a negative x, where LGAMMA returns the logarithm of the absolute value of the gamma function.

GAMMALN.PRECISE
^^^^^^^^^^^^^^^

Returns the natural logarithm of the gamma function.

.. code-block:: sql

  -- =GAMMALN.PRECISE(x)
  VALUES LGAMMA(/*x*/);
  -- =GAMMALN.PRECISE(10)
  VALUES LGAMMA(10);
  -- COL1: 12.801827480081e0

The spreadsheet returns #NUM! for a negative x, where LGAMMA returns the logarithm of the absolute value of the gamma function.

GAUSS
^^^^^

Returns the probability that a standard normal value lies between the mean and z standard deviations from it.

.. code-block:: sql

  -- =GAUSS(z)
  VALUES ERF(/*z*/ / SQRT(2e0)) / 2;
  -- =GAUSS(2)
  VALUES ERF(2 / SQRT(2e0)) / 2;
  -- COL1: 0.477249868052e0

GEOMEAN
^^^^^^^

Returns the geometric mean of positive values.

.. code-block:: sql

  -- =GEOMEAN(number1)
  SELECT EXP(AVG(LN(/*number1*/))) FROM /*table*/;
  -- =GEOMEAN(B2:B5)
  SELECT EXP(AVG(LN(y))) FROM points;
  -- COL1: 4.462928499813e0

GROWTH
^^^^^^

Predicts values on the exponential curve fitted to known values.

.. code-block:: sql

  -- =GROWTH(known_ys, known_xs, new_xs)
  SELECT EXP(REGR_INTERCEPT(LN(/*known_ys*/), /*known_xs*/) + REGR_SLOPE(LN(/*known_ys*/), /*known_xs*/) * /*new_xs*/) FROM /*table*/;
  -- =GROWTH(B2:B5, A2:A5, 5)
  SELECT EXP(REGR_INTERCEPT(LN(y), x) + REGR_SLOPE(LN(y), x) * 5)
  FROM points;
  -- COL1: 14.0839625106e0

This works for a single x column only.

HARMEAN
^^^^^^^

Returns the harmonic mean of positive values.

.. code-block:: sql

  -- =HARMEAN(number1)
  SELECT COUNT(/*number1*/) / SUM(1 / /*number1*/) FROM /*table*/;
  -- =HARMEAN(B2:B5)
  SELECT COUNT(y) / SUM(1 / y) FROM points;
  -- COL1: 3.863445797564e0

HYPGEOM.DIST
^^^^^^^^^^^^

Returns the probability of a number of successes in a sample drawn without replacement.

.. code-block:: sql

  -- =HYPGEOM.DIST(sample_s, number_sample, population_s, number_pop, FALSE)
  VALUES (FACTORIAL(/*population_s*/) / (FACTORIAL(/*sample_s*/) * FACTORIAL(/*population_s*/ - /*sample_s*/)))
    * (FACTORIAL(/*number_pop*/ - /*population_s*/) / (FACTORIAL(/*number_sample*/ - /*sample_s*/)
      * FACTORIAL(/*number_pop*/ - /*population_s*/ - /*number_sample*/ + /*sample_s*/)))
    / (FACTORIAL(/*number_pop*/) / (FACTORIAL(/*number_sample*/) * FACTORIAL(/*number_pop*/ - /*number_sample*/)) * 1e0);
  -- =HYPGEOM.DIST(1, 2, 3, 6, FALSE)
  VALUES (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
    * (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
    / (FACTORIAL(6) / (FACTORIAL(2) * FACTORIAL(4)) * 1e0);
  -- COL1: 0.6e0

This is COMBIN(3, 1) * COMBIN(3, 1) / COMBIN(6, 2), each written with FACTORIAL, and the 1e0 makes the last division approximate instead of an integer division. For cumulative TRUE, add up the terms for 0 to sample_s.

INTERCEPT
^^^^^^^^^

Returns where the straight line fitted to known values crosses the y-axis.

.. code-block:: sql

  -- =INTERCEPT(known_ys, known_xs)
  SELECT REGR_INTERCEPT(/*known_ys*/, /*known_xs*/) FROM /*table*/;
  -- =INTERCEPT(B2:B5, A2:A5)
  SELECT REGR_INTERCEPT(y, x) FROM points;
  -- COL1: -0.05e0

KURT
^^^^

Returns the sample excess kurtosis, a measure of how heavy the tails are.

.. code-block:: sql

  -- =KURT(number1)
  SELECT COUNT(*) * (COUNT(*) + 1) * SUM(POWER((/*number1*/ - a) / s, 4)) / ((COUNT(*) - 1) * (COUNT(*) - 2) * (COUNT(*) - 3))
    - 3e0 * POWER(COUNT(*) - 1, 2) / ((COUNT(*) - 2) * (COUNT(*) - 3))
  FROM /*table*/, (SELECT AVG(/*number1*/) AS a, STDDEV_SAMP(/*number1*/) AS s FROM /*table*/) AS m;
  -- =KURT(B2:B5)
  SELECT COUNT(*) * (COUNT(*) + 1) * SUM(POWER((y - a) / s, 4))
           / ((COUNT(*) - 1) * (COUNT(*) - 2) * (COUNT(*) - 3))
         - 3e0 * POWER(COUNT(*) - 1, 2) / ((COUNT(*) - 2) * (COUNT(*) - 3))
  FROM points, (SELECT AVG(y) AS a, STDDEV_SAMP(y) AS s FROM points) AS m;
  -- COL1: -0.641519590083e0

LARGE
^^^^^

Returns the k-th largest value.

.. code-block:: sql

  -- =LARGE(array, k)
  SELECT /*array*/ FROM /*table*/ ORDER BY /*array*/ DESC OFFSET /*k*/ - 1 ROWS FETCH FIRST 1 ROW ONLY;
  -- =LARGE(C2:C5, 2)
  SELECT price FROM products ORDER BY price DESC
  OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
  -- PRICE: 3.00

OFFSET is k - 1.

LINEST
^^^^^^

Returns the slope and intercept of the straight line fitted to known values.

.. code-block:: sql

  -- =LINEST(known_ys, known_xs)
  SELECT REGR_SLOPE(/*known_ys*/, /*known_xs*/) AS m, REGR_INTERCEPT(/*known_ys*/, /*known_xs*/) AS b FROM /*table*/;
  -- =LINEST(B2:B5, A2:A5)
  SELECT REGR_SLOPE(y, x) AS m, REGR_INTERCEPT(y, x) AS b FROM points;
  -- M: 2.04e0 B: -0.05e0

This works for a single x column only, and without the extra statistics.

LOGEST
^^^^^^

Returns the base and constant of the exponential curve fitted to known values.

.. code-block:: sql

  -- =LOGEST(known_ys, known_xs)
  SELECT EXP(REGR_SLOPE(LN(/*known_ys*/), /*known_xs*/)) AS m, EXP(REGR_INTERCEPT(LN(/*known_ys*/), /*known_xs*/)) AS b FROM /*table*/;
  -- =LOGEST(B2:B5, A2:A5)
  SELECT EXP(REGR_SLOPE(LN(y), x)) AS m, EXP(REGR_INTERCEPT(LN(y), x)) AS b
  FROM points;
  -- M: 1.583587162731e0 B: 1.414213562373e0

This works for a single x column only, and without the extra statistics.

LOGNORM.DIST
^^^^^^^^^^^^

Returns the lognormal distribution.

.. code-block:: sql

  -- =LOGNORM.DIST(x, mean, standard_dev, TRUE)
  VALUES 0.5 * ERFC(-(LN(/*x*/) - /*mean*/) / (/*standard_dev*/ * SQRT(2e0)));
  -- =LOGNORM.DIST(2, 0, 1, TRUE)
  VALUES 0.5 * ERFC(-(LN(2e0) - 0) / (1e0 * SQRT(2e0)));
  -- COL1: 0.755891404214e0

  -- =LOGNORM.DIST(x, mean, standard_dev, FALSE)
  VALUES EXP(-POWER(LN(/*x*/) - /*mean*/, 2) / (2 * POWER(/*standard_dev*/, 2))) / (/*x*/ * /*standard_dev*/ * SQRT(2 * PI()));
  -- =LOGNORM.DIST(2, 0, 1, FALSE)
  VALUES EXP(-POWER(LN(2e0) - 0, 2) / (2 * POWER(1e0, 2)))
    / (2 * 1e0 * SQRT(2 * PI()));
  -- COL1: 0.156874019279e0

LOGNORM.INV
^^^^^^^^^^^

.. code-block:: text

  =LOGNORM.INV(probability, mean, standard_dev)

Returns the inverse of the cumulative lognormal distribution.

No equivalent.

MARGINOFERROR
^^^^^^^^^^^^^

.. code-block:: text

  =MARGINOFERROR(range, confidence)

Returns the margin of error of a sample mean at a confidence level. Only in Google Sheets.

No equivalent.

MAX
^^^

Returns the largest value.

.. code-block:: sql

  -- =MAX(number1)
  SELECT MAX(/*number1*/) FROM /*table*/;
  -- =MAX(C2:C5)
  SELECT MAX(price) FROM products;
  -- COL1: 4.00

MAXA
^^^^

Returns the largest value, counting text as 0 and logical values as 0 or 1.

.. code-block:: sql

  -- =MAXA(value1)
  SELECT MAX(COALESCE(/*value1*/, 0)) FROM /*table*/;
  -- =MAXA(D2:D5)
  SELECT MAX(COALESCE(qty, 0)) FROM products;
  -- COL1: 40

A column holds only one type, so the nearest match to text counting as 0 is a NULL counting as 0; for truly empty cells, which are skipped, use MAX.

MAXIFS
^^^^^^

Returns the largest value in the rows that meet conditions.

.. code-block:: sql

  -- =MAXIFS(max_range, criteria_range1, criteria1)
  SELECT MAX(/*max_range*/) FILTER (WHERE /*criteria_range1*/ /*criteria1*/) FROM /*table*/;
  -- =MAXIFS(C2:C5, D2:D5, ">=10")
  SELECT MAX(price) FILTER (WHERE qty >= 10) FROM products;
  -- COL1: 1.50

MEDIAN
^^^^^^

Returns the middle value.

.. code-block:: sql

  -- =MEDIAN(number1)
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY /*number1*/) FROM /*table*/;
  -- =MEDIAN(C2:C5)
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
  FROM products;
  -- COL1: 2.25e0

MIN
^^^

Returns the smallest value.

.. code-block:: sql

  -- =MIN(number1)
  SELECT MIN(/*number1*/) FROM /*table*/;
  -- =MIN(C2:C5)
  SELECT MIN(price) FROM products;
  -- COL1: 0.25

MINA
^^^^

Returns the smallest value, counting text as 0 and logical values as 0 or 1.

.. code-block:: sql

  -- =MINA(value1)
  SELECT MIN(COALESCE(/*value1*/, 0)) FROM /*table*/;
  -- =MINA(D2:D5)
  SELECT MIN(COALESCE(qty, 0)) FROM products;
  -- COL1: 0

A column holds only one type, so the nearest match to text counting as 0 is a NULL counting as 0; for truly empty cells, which are skipped, use MIN.

MINIFS
^^^^^^

Returns the smallest value in the rows that meet conditions.

.. code-block:: sql

  -- =MINIFS(min_range, criteria_range1, criteria1)
  SELECT MIN(/*min_range*/) FILTER (WHERE /*criteria_range1*/ /*criteria1*/) FROM /*table*/;
  -- =MINIFS(C2:C5, D2:D5, ">=10")
  SELECT MIN(price) FILTER (WHERE qty >= 10) FROM products;
  -- COL1: 0.25

MODE.MULT
^^^^^^^^^

Returns every value that is the most frequent.

.. code-block:: sql

  -- =MODE.MULT(number1)
  SELECT /*number1*/ FROM /*table*/ GROUP BY /*number1*/
  HAVING COUNT(*) >= ALL (SELECT COUNT(*) FROM /*table*/ GROUP BY /*number1*/) ORDER BY /*number1*/;
  -- =MODE.MULT(1, 2, 2, 3, 3)
  SELECT v FROM (VALUES (1), (2), (2), (3), (3)) AS t (v)
  GROUP BY v HAVING COUNT(*) >= ALL (SELECT COUNT(*)
    FROM (VALUES (1), (2), (2), (3), (3)) AS u (v) GROUP BY v)
  ORDER BY v;
  -- V: 2
  -- V: 3

MODE.SNGL
^^^^^^^^^

Returns the most frequent value.

.. code-block:: sql

  -- =MODE.SNGL(number1)
  SELECT MODE() WITHIN GROUP (ORDER BY /*number1*/) FROM /*table*/;
  -- =MODE.SNGL(1, 2, 2, 3)
  SELECT MODE() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
  -- COL1: 2

On a tie this returns the first value in the ``ORDER BY`` order (the smallest
with ``ASC``), where the spreadsheet returns the one that comes first in the
sheet.

NEGBINOM.DIST
^^^^^^^^^^^^^

Returns the probability of a number of failures before a number of successes.

.. code-block:: sql

  -- =NEGBINOM.DIST(number_f, number_s, probability_s, FALSE)
  VALUES FACTORIAL(/*number_f*/ + /*number_s*/ - 1) / (FACTORIAL(/*number_s*/ - 1) * FACTORIAL(/*number_f*/))
    * POWER(/*probability_s*/, /*number_s*/) * POWER(1 - /*probability_s*/, /*number_f*/);
  -- =NEGBINOM.DIST(2, 3, 0.5, FALSE)
  VALUES FACTORIAL(2 + 3 - 1) / (FACTORIAL(3 - 1) * FACTORIAL(2))
    * POWER(0.5e0, 3) * POWER(1 - 0.5e0, 2);
  -- COL1: 0.1875e0

The binomial coefficient COMBIN(number_f + number_s - 1, number_s - 1) is written with FACTORIAL. For cumulative TRUE, add up the terms for 0 to number_f.

NORM.DIST
^^^^^^^^^

Returns the normal distribution.

.. code-block:: sql

  -- =NORM.DIST(x, mean, standard_dev, TRUE)
  VALUES 0.5 * ERFC(-(/*x*/ - /*mean*/) / (/*standard_dev*/ * SQRT(2e0)));
  -- =NORM.DIST(1, 0, 1, TRUE)
  VALUES 0.5 * ERFC(-(1 - 0) / (1e0 * SQRT(2e0)));
  -- COL1: 0.841344746069e0

  -- =NORM.DIST(x, mean, standard_dev, FALSE)
  VALUES EXP(-POWER(/*x*/ - /*mean*/, 2) / (2 * POWER(/*standard_dev*/, 2))) / (/*standard_dev*/ * SQRT(2 * PI()));
  -- =NORM.DIST(1, 0, 1, FALSE)
  VALUES EXP(-POWER(1 - 0, 2) / (2 * POWER(1e0, 2)))
    / (1e0 * SQRT(2 * PI()));
  -- COL1: 0.241970724519e0

NORM.INV
^^^^^^^^

.. code-block:: text

  =NORM.INV(probability, mean, standard_dev)

Returns the inverse of the cumulative normal distribution.

No equivalent.

NORM.S.DIST
^^^^^^^^^^^

Returns the standard normal distribution.

.. code-block:: sql

  -- =NORM.S.DIST(z, TRUE)
  VALUES 0.5 * ERFC(-/*z*/ / SQRT(2e0));
  -- =NORM.S.DIST(1, TRUE)
  VALUES 0.5 * ERFC(-1e0 / SQRT(2e0));
  -- COL1: 0.841344746069e0

  -- =NORM.S.DIST(z, FALSE)
  VALUES EXP(-POWER(/*z*/, 2) / 2) / SQRT(2 * PI());
  -- =NORM.S.DIST(1, FALSE)
  VALUES EXP(-POWER(1e0, 2) / 2) / SQRT(2 * PI());
  -- COL1: 0.241970724519e0

NORM.S.INV
^^^^^^^^^^

.. code-block:: text

  =NORM.S.INV(probability)

Returns the inverse of the cumulative standard normal distribution.

No equivalent.

PEARSON
^^^^^^^

Returns the Pearson correlation coefficient of two sets of values.

.. code-block:: sql

  -- =PEARSON(array1, array2)
  SELECT CORR(/*array1*/, /*array2*/) FROM /*table*/;
  -- =PEARSON(B2:B5, A2:A5)
  SELECT CORR(y, x) FROM points;
  -- COL1: 0.998992298024e0

PERCENTILE.EXC
^^^^^^^^^^^^^^

Returns the k-th percentile, interpolating between values, for k strictly between 0 and 1.

.. code-block:: sql

  -- =PERCENTILE.EXC(array, k)
  SELECT PERCENTILE_CONT(((/*count*/ + 1) * /*k*/ - 1) / (/*count*/ - 1)) WITHIN GROUP (ORDER BY /*array*/) FROM /*table*/;
  -- =PERCENTILE.EXC(B2:B5, 0.25)
  SELECT PERCENTILE_CONT(((4 + 1) * 0.25e0 - 1) / (4 - 1))
    WITHIN GROUP (ORDER BY y) FROM points;
  -- COL1: 2.525e0

The 4 is the number of values: this percentile is PERCENTILE.INC at ((n + 1) * k - 1) / (n - 1). The spreadsheet gives #NUM! when that is outside 0 to 1.

PERCENTILE.INC
^^^^^^^^^^^^^^

Returns the k-th percentile, interpolating between values.

.. code-block:: sql

  -- =PERCENTILE.INC(array, k)
  SELECT PERCENTILE_CONT(/*k*/) WITHIN GROUP (ORDER BY /*array*/) FROM /*table*/;
  -- =PERCENTILE.INC(B2:B5, 0.25)
  SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY y)
  FROM points;
  -- COL1: 3.575e0

PERCENTRANK.EXC
^^^^^^^^^^^^^^^

Returns the rank of a value as a fraction strictly between 0 and 1.

.. code-block:: sql

  -- =PERCENTRANK.EXC(array, x)
  SELECT TRUNC((COUNT(*) FILTER (WHERE /*array*/ < /*x*/) + 1) / (COUNT(*) + 1e0), 3) FROM /*table*/;
  -- =PERCENTRANK.EXC(C2:C5, 3)
  SELECT TRUNC((COUNT(*) FILTER (WHERE price < 3) + 1)
    / (COUNT(*) + 1e0), 3) FROM products;
  -- COL1: 0.6e0

This is only right when x is one of the values; the spreadsheet interpolates between values otherwise.

PERCENTRANK.INC
^^^^^^^^^^^^^^^

Returns the rank of a value as a fraction from 0 to 1.

.. code-block:: sql

  -- =PERCENTRANK.INC(array, x)
  SELECT TRUNC(COUNT(*) FILTER (WHERE /*array*/ < /*x*/) / (COUNT(*) - 1e0), 3) FROM /*table*/;
  -- =PERCENTRANK.INC(C2:C5, 3)
  SELECT TRUNC(COUNT(*) FILTER (WHERE price < 3)
    / (COUNT(*) - 1e0), 3) FROM products;
  -- COL1: 0.666e0

This is only right when x is one of the values; the spreadsheet interpolates between values otherwise.

PERMUT
^^^^^^

Returns the number of ordered ways to choose some items from a set.

.. code-block:: sql

  -- =PERMUT(number, number_chosen)
  VALUES FACTORIAL(/*number*/) / FACTORIAL(/*number*/ - /*number_chosen*/);
  -- =PERMUT(5, 2)
  VALUES FACTORIAL(5) / FACTORIAL(5 - 2);
  -- COL1: 20

PERMUTATIONA
^^^^^^^^^^^^

Returns the number of ordered ways to choose some items from a set when items can repeat.

.. code-block:: sql

  -- =PERMUTATIONA(number, number_chosen)
  VALUES POWER(/*number*/, /*number_chosen*/);
  -- =PERMUTATIONA(5, 2)
  VALUES POWER(5, 2);
  -- COL1: 25e0

PHI
^^^

Returns the density of the standard normal distribution.

.. code-block:: sql

  -- =PHI(x)
  VALUES EXP(-POWER(/*x*/, 2) / 2) / SQRT(2 * PI());
  -- =PHI(0.75)
  VALUES EXP(-POWER(0.75e0, 2) / 2) / SQRT(2 * PI());
  -- COL1: 0.301137432155e0

POISSON.DIST
^^^^^^^^^^^^

Returns the Poisson probability of a number of events.

.. code-block:: sql

  -- =POISSON.DIST(x, mean, FALSE)
  VALUES EXP(-/*mean*/) * POWER(/*mean*/, /*x*/) / FACTORIAL(/*x*/);
  -- =POISSON.DIST(2, 3, FALSE)
  VALUES EXP(-3e0) * POWER(3e0, 2) / FACTORIAL(2);
  -- COL1: 0.224041807655e0

For cumulative TRUE, add up the terms for 0 to x.

PROB
^^^^

Returns the probability that a value falls between two limits.

.. code-block:: sql

  -- =PROB(x_range, prob_range, lower_limit, upper_limit)
  SELECT SUM(/*prob_range*/) FROM /*table*/ WHERE /*x_range*/ BETWEEN /*lower_limit*/ AND /*upper_limit*/;
  -- =PROB({0; 1; 2; 3}, {0.2; 0.3; 0.1; 0.4}, 1, 2)
  SELECT SUM(p) FROM (VALUES (0, 0.2), (1, 0.3), (2, 0.1), (3, 0.4))
    AS t (x, p) WHERE x BETWEEN 1 AND 2;
  -- COL1: 0.4

  -- =PROB(x_range, prob_range, lower_limit)
  SELECT SUM(/*prob_range*/) FROM /*table*/ WHERE /*x_range*/ = /*lower_limit*/;
  -- =PROB({0; 1; 2; 3}, {0.2; 0.3; 0.1; 0.4}, 1)
  SELECT SUM(p) FROM (VALUES (0, 0.2), (1, 0.3), (2, 0.1), (3, 0.4)) AS t (x, p) WHERE x = 1;
  -- COL1: 0.3

QUARTILE.EXC
^^^^^^^^^^^^

Returns a quartile, interpolating between values, for quartiles 1 to 3.

.. code-block:: sql

  -- =QUARTILE.EXC(array, quart)
  SELECT PERCENTILE_CONT(((/*count*/ + 1) * /*quart*/ / 4e0 - 1) / (/*count*/ - 1)) WITHIN GROUP (ORDER BY /*array*/) FROM /*table*/;
  -- =QUARTILE.EXC(B2:B5, 1)
  SELECT PERCENTILE_CONT(((4 + 1) * 0.25e0 - 1) / (4 - 1))
    WITHIN GROUP (ORDER BY y) FROM points;
  -- COL1: 2.525e0

The 4 is the number of values, as for PERCENTILE.EXC with k = quart / 4.

QUARTILE.INC
^^^^^^^^^^^^

Returns a quartile, interpolating between values.

.. code-block:: sql

  -- =QUARTILE.INC(array, quart)
  SELECT PERCENTILE_CONT(/*quart*/ / 4e0) WITHIN GROUP (ORDER BY /*array*/) FROM /*table*/;
  -- =QUARTILE.INC(B2:B5, 1)
  SELECT PERCENTILE_CONT(1 / 4e0) WITHIN GROUP (ORDER BY y)
  FROM points;
  -- COL1: 3.575e0

RANK.AVG
^^^^^^^^

Returns the rank of a number among other numbers, with ties sharing their average rank.

.. code-block:: sql

  -- =RANK.AVG(number, ref)
  SELECT COUNT(*) FILTER (WHERE /*ref*/ > /*number*/) + (COUNT(*) FILTER (WHERE /*ref*/ = /*number*/) + 1) / 2.0 FROM /*table*/;
  -- =RANK.AVG(3, C2:C5)
  SELECT COUNT(*) FILTER (WHERE price > 3)
    + (COUNT(*) FILTER (WHERE price = 3) + 1) / 2.0 FROM products;
  -- COL1: 2.0

Use price < 3 for order 1.

RANK.EQ
^^^^^^^

Returns the rank of a number among other numbers, with ties sharing a rank.

.. code-block:: sql

  -- =RANK.EQ(number, ref)
  SELECT RANK(/*number*/) WITHIN GROUP (ORDER BY /*ref*/ DESC) FROM /*table*/;
  -- =RANK.EQ(3, C2:C5)
  SELECT RANK(3) WITHIN GROUP (ORDER BY price DESC)
  FROM products;
  -- COL1: 2

  -- =RANK.EQ(number, ref, 1)
  SELECT RANK(/*number*/) WITHIN GROUP (ORDER BY /*ref*/) FROM /*table*/;
  -- =RANK.EQ(3, C2:C5, 1)
  SELECT RANK(3) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 3

Use ORDER BY price (ascending) for order 1.

RSQ
^^^

Returns the square of the correlation coefficient.

.. code-block:: sql

  -- =RSQ(known_ys, known_xs)
  SELECT REGR_R2(/*known_ys*/, /*known_xs*/) FROM /*table*/;
  -- =RSQ(B2:B5, A2:A5)
  SELECT REGR_R2(y, x) FROM points;
  -- COL1: 0.997985611511e0

SKEW
^^^^

Returns the sample skewness, a measure of how lopsided the values are.

.. code-block:: sql

  -- =SKEW(number1)
  SELECT COUNT(*) * SUM(POWER((/*number1*/ - a) / s, 3)) / ((COUNT(*) - 1) * (COUNT(*) - 2))
  FROM /*table*/, (SELECT AVG(/*number1*/) AS a, STDDEV_SAMP(/*number1*/) AS s FROM /*table*/) AS m;
  -- =SKEW(B2:B5)
  SELECT COUNT(*) * SUM(POWER((y - a) / s, 3))
         / ((COUNT(*) - 1) * (COUNT(*) - 2))
  FROM points, (SELECT AVG(y) AS a, STDDEV_SAMP(y) AS s FROM points) AS m;
  -- COL1: 0.096058424862e0

SKEW.P
^^^^^^

Returns the population skewness, a measure of how lopsided the values are.

.. code-block:: sql

  -- =SKEW.P(number1)
  SELECT AVG(POWER((/*number1*/ - a) / s, 3))
  FROM /*table*/, (SELECT AVG(/*number1*/) AS a, STDDEV_POP(/*number1*/) AS s FROM /*table*/) AS m;
  -- =SKEW.P(B2:B5)
  SELECT AVG(POWER((y - a) / s, 3))
  FROM points, (SELECT AVG(y) AS a, STDDEV_POP(y) AS s FROM points) AS m;
  -- COL1: 0.055459357452e0

SLOPE
^^^^^

Returns the slope of the straight line fitted to known values.

.. code-block:: sql

  -- =SLOPE(known_ys, known_xs)
  SELECT REGR_SLOPE(/*known_ys*/, /*known_xs*/) FROM /*table*/;
  -- =SLOPE(B2:B5, A2:A5)
  SELECT REGR_SLOPE(y, x) FROM points;
  -- COL1: 2.04e0

SMALL
^^^^^

Returns the k-th smallest value.

.. code-block:: sql

  -- =SMALL(array, k)
  SELECT /*array*/ FROM /*table*/ ORDER BY /*array*/ OFFSET /*k*/ - 1 ROWS FETCH FIRST 1 ROW ONLY;
  -- =SMALL(C2:C5, 2)
  SELECT price FROM products ORDER BY price
  OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
  -- PRICE: 1.50

OFFSET is k - 1.

STANDARDIZE
^^^^^^^^^^^

Returns how many standard deviations a value is from a mean.

.. code-block:: sql

  -- =STANDARDIZE(x, mean, standard_dev)
  VALUES (/*x*/ - /*mean*/) / /*standard_dev*/;
  -- =STANDARDIZE(42, 40, 1.5)
  VALUES (42 - 40) / 1.5e0;
  -- COL1: 1.333333333333e0

STDEV.P
^^^^^^^

Returns the standard deviation of a whole population.

.. code-block:: sql

  -- =STDEV.P(number1)
  SELECT STDDEV_POP(/*number1*/) FROM /*table*/;
  -- =STDEV.P(B2:B5)
  SELECT STDDEV_POP(y) FROM points;
  -- COL1: 2.283090011366e0

STDEV.S
^^^^^^^

Returns the standard deviation of a sample.

.. code-block:: sql

  -- =STDEV.S(number1)
  SELECT STDDEV_SAMP(/*number1*/) FROM /*table*/;
  -- =STDEV.S(B2:B5)
  SELECT STDDEV_SAMP(y) FROM points;
  -- COL1: 2.636285265293e0

STDEVA
^^^^^^

Returns the standard deviation of a sample, counting text as 0 and logical values as 0 or 1.

.. code-block:: sql

  -- =STDEVA(value1)
  SELECT STDDEV_SAMP(COALESCE(/*value1*/, 0)) FROM /*table*/;
  -- =STDEVA(D2:D5)
  SELECT STDDEV_SAMP(COALESCE(qty, 0)) FROM products;
  -- COL1: 17.969882210707e0

A column holds only one type, so the nearest match to text counting as 0 is a NULL counting as 0; for truly empty cells, which are skipped, use STDEV.S.

STDEVPA
^^^^^^^

Returns the standard deviation of a whole population, counting text as 0 and logical values as 0 or 1.

.. code-block:: sql

  -- =STDEVPA(value1)
  SELECT STDDEV_POP(COALESCE(/*value1*/, 0)) FROM /*table*/;
  -- =STDEVPA(D2:D5)
  SELECT STDDEV_POP(COALESCE(qty, 0)) FROM products;
  -- COL1: 15.562374497486e0

A column holds only one type, so the nearest match to text counting as 0 is a NULL counting as 0; for truly empty cells, which are skipped, use STDEV.P.

STEYX
^^^^^

Returns the standard error of the y values predicted by a straight-line fit.

.. code-block:: sql

  -- =STEYX(known_ys, known_xs)
  SELECT SQRT((REGR_SYY(/*known_ys*/, /*known_xs*/) - POWER(REGR_SXY(/*known_ys*/, /*known_xs*/), 2) / REGR_SXX(/*known_ys*/, /*known_xs*/))
    / (REGR_COUNT(/*known_ys*/, /*known_xs*/) - 2)) FROM /*table*/;
  -- =STEYX(B2:B5, A2:A5)
  SELECT SQRT((REGR_SYY(y, x) - POWER(REGR_SXY(y, x), 2) / REGR_SXX(y, x))
    / (REGR_COUNT(y, x) - 2)) FROM points;
  -- COL1: 0.144913767462e0

T.DIST
^^^^^^

.. code-block:: text

  =T.DIST(x, deg_freedom, cumulative)

Returns the left-tailed Student's t-distribution.

No equivalent.

T.DIST.2T
^^^^^^^^^

.. code-block:: text

  =T.DIST.2T(x, deg_freedom)

Returns the two-tailed Student's t-distribution.

No equivalent.

T.DIST.RT
^^^^^^^^^

.. code-block:: text

  =T.DIST.RT(x, deg_freedom)

Returns the right-tailed Student's t-distribution.

No equivalent.

T.INV
^^^^^

.. code-block:: text

  =T.INV(probability, deg_freedom)

Returns the inverse of the left-tailed Student's t-distribution.

No equivalent.

T.INV.2T
^^^^^^^^

.. code-block:: text

  =T.INV.2T(probability, deg_freedom)

Returns the inverse of the two-tailed Student's t-distribution.

No equivalent.

T.TEST
^^^^^^

.. code-block:: text

  =T.TEST(array1, array2, tails, type)

Returns the p-value of a Student's t-test.

No equivalent.

TREND
^^^^^

Predicts values on the straight line fitted to known values.

.. code-block:: sql

  -- =TREND(known_ys, known_xs, new_xs)
  SELECT REGR_INTERCEPT(/*known_ys*/, /*known_xs*/) + REGR_SLOPE(/*known_ys*/, /*known_xs*/) * /*new_xs*/ FROM /*table*/;
  -- =TREND(B2:B5, A2:A5, 5)
  SELECT REGR_INTERCEPT(y, x) + REGR_SLOPE(y, x) * 5 FROM points;
  -- COL1: 10.15e0

This works for a single x column only.

TRIMMEAN
^^^^^^^^

Returns the mean after leaving out a fraction of the smallest and largest values.

.. code-block:: sql

  -- =TRIMMEAN(array, percent)
  SELECT AVG(/*array*/) FROM (SELECT /*array*/ FROM /*table*/ ORDER BY /*array*/
    OFFSET /*count * percent / 2*/ ROWS FETCH FIRST /*count - count * percent*/ ROWS ONLY) AS t;
  -- =TRIMMEAN(C2:C5, 0.5)
  SELECT AVG(price) FROM (SELECT price FROM products ORDER BY price
    OFFSET 1 ROW FETCH FIRST 2 ROWS ONLY) AS t;
  -- COL1: 2.25

OFFSET is the number left out at each end, n * percent / 2 rounded down, and FETCH is the number kept.

VAR.P
^^^^^

Returns the variance of a whole population.

.. code-block:: sql

  -- =VAR.P(number1)
  SELECT VAR_POP(/*number1*/) FROM /*table*/;
  -- =VAR.P(B2:B5)
  SELECT VAR_POP(y) FROM points;
  -- COL1: 5.2125e0

VAR.S
^^^^^

Returns the variance of a sample.

.. code-block:: sql

  -- =VAR.S(number1)
  SELECT VAR_SAMP(/*number1*/) FROM /*table*/;
  -- =VAR.S(B2:B5)
  SELECT VAR_SAMP(y) FROM points;
  -- COL1: 6.95e0

VARA
^^^^

Returns the variance of a sample, counting text as 0 and logical values as 0 or 1.

.. code-block:: sql

  -- =VARA(value1)
  SELECT VAR_SAMP(COALESCE(/*value1*/, 0)) FROM /*table*/;
  -- =VARA(D2:D5)
  SELECT VAR_SAMP(COALESCE(qty, 0)) FROM products;
  -- COL1: 322.916666666667e0

A column holds only one type, so the nearest match to text counting as 0 is a NULL counting as 0; for truly empty cells, which are skipped, use VAR.S.

VARPA
^^^^^

Returns the variance of a whole population, counting text as 0 and logical values as 0 or 1.

.. code-block:: sql

  -- =VARPA(value1)
  SELECT VAR_POP(COALESCE(/*value1*/, 0)) FROM /*table*/;
  -- =VARPA(D2:D5)
  SELECT VAR_POP(COALESCE(qty, 0)) FROM products;
  -- COL1: 242.1875e0

A column holds only one type, so the nearest match to text counting as 0 is a NULL counting as 0; for truly empty cells, which are skipped, use VAR.P.

WEIBULL.DIST
^^^^^^^^^^^^

Returns the Weibull distribution.

.. code-block:: sql

  -- =WEIBULL.DIST(x, alpha, beta, TRUE)
  VALUES 1 - EXP(-POWER(/*x*/ / /*beta*/, /*alpha*/));
  -- =WEIBULL.DIST(2, 1.5, 3, TRUE)
  VALUES 1 - EXP(-POWER(2 / 3e0, 1.5));
  -- COL1: 0.419770204025e0

For cumulative FALSE, use 1.5 / 3 * POWER(2 / 3e0, 0.5) * EXP(-POWER(2 / 3e0, 1.5)).

Z.TEST
^^^^^^

Returns the one-tailed p-value of a z-test.

.. code-block:: sql

  -- =Z.TEST(array, x)
  SELECT 0.5 * ERFC((AVG(/*array*/) - /*x*/) / (STDDEV_SAMP(/*array*/) / SQRT(COUNT(/*array*/))) / SQRT(2e0)) FROM /*table*/;
  -- =Z.TEST(B2:B5, 4)
  SELECT 0.5 * ERFC((AVG(y) - 4) / (STDDEV_SAMP(y) / SQRT(COUNT(y))) / SQRT(2e0))
  FROM points;
  -- COL1: 0.212848833428e0

  -- =Z.TEST(array, x, sigma)
  SELECT 0.5 * ERFC((AVG(/*array*/) - /*x*/) / (/*sigma*/ / SQRT(COUNT(/*array*/))) / SQRT(2e0)) FROM /*table*/;
  -- =Z.TEST(B2:B5, 4, 2)
  SELECT 0.5 * ERFC((AVG(y) - 4) / (2 / SQRT(COUNT(y))) / SQRT(2e0))
  FROM points;
  -- COL1: 0.146859056376e0

Text Functions
--------------

ARRAYTOTEXT
^^^^^^^^^^^

Joins the values of a range into one piece of text. Only in Excel.

.. code-block:: sql

  -- =ARRAYTOTEXT(array)
  SELECT LISTAGG(/*array*/, ', ') WITHIN GROUP (ORDER BY /*key*/) FROM /*table*/;
  -- =ARRAYTOTEXT(B2:B5)
  SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY sku) FROM products;
  -- COL1: Apple, Banana, Cherry, Date

ASC
^^^

.. code-block:: text

  =ASC(text)

Changes full-width characters to half-width ones. Only in Excel.

No equivalent.

BAHTTEXT
^^^^^^^^

.. code-block:: text

  =BAHTTEXT(number)

Spells out a number in Thai words as an amount of baht. Only in Excel.

No equivalent.

CHAR
^^^^

Returns the character for a character code.

.. code-block:: sql

  -- =CHAR(number)
  VALUES CHR(/*number*/);
  -- =CHAR(65)
  VALUES CHR(65);
  -- COL1: A

The number is a Unicode code point, which is the same as the spreadsheet's
character code for plain ASCII (below 128), but not always above that.

CLEAN
^^^^^

.. code-block:: text

  =CLEAN(text)

Removes the characters that can't be printed from text.

No equivalent.

CODE
^^^^

Returns the character code of the first character of text.

.. code-block:: sql

  -- =CODE(text)
  VALUES UNICODE(/*text*/);
  -- =CODE("Apple")
  VALUES UNICODE('Apple');
  -- COL1: 65

The result is a Unicode code point, which is the same as the spreadsheet's
character code for plain ASCII (below 128), but not always above that. The code
of empty text is 0 rather than ``#VALUE!``.

CONCAT
^^^^^^

Joins pieces of text together.

.. code-block:: sql

  -- =CONCAT(text1, text2, ...)
  VALUES /*text1*/ || /*text2*/ || ...;
  -- =CONCAT("Apple", "pie")
  VALUES 'Apple' || 'pie';
  -- COL1: Applepie

Joining ``NULL`` gives ``NULL``, where an empty cell adds nothing, so use
``COALESCE(x, '')``. For a range, use ``LISTAGG(name, '')``.

CONCATENATE
^^^^^^^^^^^

Joins pieces of text together.

.. code-block:: sql

  -- =CONCATENATE(text1, text2, ...)
  VALUES /*text1*/ || /*text2*/ || ...;
  -- =CONCATENATE("Apple", "pie")
  VALUES 'Apple' || 'pie';
  -- COL1: Applepie

Joining ``NULL`` gives ``NULL``, where an empty cell adds nothing, so use
``COALESCE(x, '')``.

DBCS
^^^^

.. code-block:: text

  =DBCS(text)

Changes half-width characters to full-width ones. Only in Excel.

No equivalent.

DETECTLANGUAGE
^^^^^^^^^^^^^^

.. code-block:: text

  =DETECTLANGUAGE(text)

Works out which language text is written in.

No equivalent.

DOLLAR
^^^^^^

Formats a number as currency text.

.. code-block:: sql

  -- =DOLLAR(number)
  VALUES '$' || CAST(CAST(ROUND(/*number*/, 2) AS DECIMAL(10, 2)) AS VARCHAR(20));
  -- =DOLLAR(4.5)
  VALUES '$' || CAST(CAST(ROUND(4.5, 2) AS DECIMAL(10, 2)) AS VARCHAR(20));
  -- COL1: $4.50

There are no thousands separators, and a negative number shows as ``$-4.50``.

EXACT
^^^^^

Checks whether two pieces of text are the same, including their case.

.. code-block:: sql

  -- =EXACT(text1, text2)
  VALUES /*text1*/ = /*text2*/;
  -- =EXACT("Apple", "apple")
  VALUES 'Apple' = 'apple';
  -- COL1: FALSE

Spaces at the end are ignored, so ``'a' = 'a '`` is TRUE.

FIND
^^^^

Returns the position of text within other text, matching case.

.. code-block:: sql

  -- =FIND(find_text, within_text)
  VALUES POSITION(/*find_text*/ IN /*within_text*/);
  -- =FIND("p", "Apple")
  VALUES POSITION('p' IN 'Apple');
  -- COL1: 2

When the text isn't found, the result is 0 rather than ``#VALUE!``.

FINDB
^^^^^

.. code-block:: text

  =FINDB(find_text, within_text, [start_num])

Returns the position of text within other text, counted in bytes. Only in
Excel.

No equivalent.

FIXED
^^^^^

Formats a number as text with a fixed number of decimal places.

.. code-block:: sql

  -- =FIXED(number, decimals, TRUE)
  VALUES CAST(CAST(ROUND(/*number*/, /*decimals*/) AS DECIMAL(10, /*decimals*/)) AS VARCHAR(20));
  -- =FIXED(1234.567, 1, TRUE)
  VALUES CAST(CAST(ROUND(1234.567, 1) AS DECIMAL(10, 1)) AS VARCHAR(20));
  -- COL1: 1234.6

There are no thousands separators.

JOIN
^^^^

Joins values with a delimiter between them. Only in Google Sheets.

.. code-block:: sql

  -- =JOIN(delimiter, value_or_array1)
  SELECT LISTAGG(/*value_or_array1*/, /*delimiter*/) WITHIN GROUP (ORDER BY /*key*/) FROM /*table*/;
  -- =JOIN(", ", B2:B5)
  SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY sku) FROM products;
  -- COL1: Apple, Banana, Cherry, Date

LEFT
^^^^

Returns the first characters of text.

.. code-block:: sql

  -- =LEFT(text, num_chars)
  VALUES SUBSTRING(/*text*/ FROM 1 FOR /*num_chars*/);
  -- =LEFT("Apple", 3)
  VALUES SUBSTRING('Apple' FROM 1 FOR 3);
  -- COL1: App

  -- =LEFT(text)
  VALUES SUBSTRING(/*text*/ FROM 1 FOR 1);
  -- =LEFT("Apple")
  VALUES SUBSTRING('Apple' FROM 1 FOR 1);
  -- COL1: A

LEFTB
^^^^^

Returns the first bytes of text. Only in Excel.

.. code-block:: sql

  -- =LEFTB(text, num_bytes)
  VALUES SUBSTRING(/*text*/ FROM 1 FOR /*num_bytes*/ USING OCTETS);
  -- =LEFTB("Apple", 3)
  VALUES SUBSTRING('Apple' FROM 1 FOR 3 USING OCTETS);
  -- COL1: App

Bytes are counted in UTF-8, so text that isn't plain ASCII counts differently.

LEN
^^^

Returns the number of characters in text.

.. code-block:: sql

  -- =LEN(text)
  VALUES CHAR_LENGTH(/*text*/);
  -- =LEN("Apple")
  VALUES CHAR_LENGTH('Apple');
  -- COL1: 5

LENB
^^^^

Returns the number of bytes in text. Only in Excel.

.. code-block:: sql

  -- =LENB(text)
  VALUES OCTET_LENGTH(/*text*/);
  -- =LENB("Apple")
  VALUES OCTET_LENGTH('Apple');
  -- COL1: 5

Bytes are counted in UTF-8, so text that isn't plain ASCII counts differently.

LOWER
^^^^^

Changes text to lower case.

.. code-block:: sql

  -- =LOWER(text)
  VALUES LOWER(/*text*/);
  -- =LOWER("Apple")
  VALUES LOWER('Apple');
  -- COL1: apple

MID
^^^

Returns characters from the middle of text.

.. code-block:: sql

  -- =MID(text, start_num, num_chars)
  VALUES SUBSTRING(/*text*/ FROM /*start_num*/ FOR /*num_chars*/);
  -- =MID("Apple", 2, 3)
  VALUES SUBSTRING('Apple' FROM 2 FOR 3);
  -- COL1: ppl

MIDB
^^^^

Returns bytes from the middle of text. Only in Excel.

.. code-block:: sql

  -- =MIDB(text, start_num, num_bytes)
  VALUES SUBSTRING(/*text*/ FROM /*start_num*/ FOR /*num_bytes*/ USING OCTETS);
  -- =MIDB("Apple", 2, 3)
  VALUES SUBSTRING('Apple' FROM 2 FOR 3 USING OCTETS);
  -- COL1: ppl

Bytes are counted in UTF-8, so text that isn't plain ASCII counts differently.

NUMBERVALUE
^^^^^^^^^^^

Converts text to a number, with a choice of separators.

.. code-block:: sql

  -- =NUMBERVALUE(text)
  VALUES CAST(/*text*/ AS DECIMAL(10, 2));
  -- =NUMBERVALUE("1234.5")
  VALUES CAST('1234.5' AS DECIMAL(10, 2));
  -- COL1: 1234.50

The text must use ``.`` for the decimal point and no group separators.

PHONETIC
^^^^^^^^

.. code-block:: text

  =PHONETIC(reference)

Returns the phonetic guide stored with Japanese text in a cell. Only in Excel.

No equivalent.

PROPER
^^^^^^

Capitalizes the first letter of each word.

.. code-block:: sql

  -- =PROPER(text)
  VALUES INITCAP(/*text*/);
  -- =PROPER("hELLO wORLD")
  VALUES INITCAP('hELLO wORLD');
  -- COL1: Hello World

A digit is part of a word, so ``INITCAP('2nd')`` is ``2nd``, where a
spreadsheet gives ``2Nd``.

REGEXEXTRACT
^^^^^^^^^^^^

.. code-block:: text

  =REGEXEXTRACT(text, pattern, [return_mode], [case_sensitivity])

Returns the part of text that matches a regular expression.

No equivalent.

REGEXMATCH
^^^^^^^^^^

Checks whether text matches a regular expression. Only in Google Sheets.

.. code-block:: sql

  -- =REGEXMATCH(text, regular_expression)
  VALUES /*text*/ SIMILAR TO /*regular_expression, as a SIMILAR TO pattern*/;
  -- =REGEXMATCH("Apple", "^[AB]")
  VALUES 'Apple' SIMILAR TO '[AB]%';
  -- COL1: TRUE

The pattern must match the whole text, and ``%`` and ``_`` take the place of
``.*`` and ``.``.

REGEXREPLACE
^^^^^^^^^^^^

.. code-block:: text

  =REGEXREPLACE(text, pattern, replacement, [occurrence], [case_sensitivity])

Replaces the parts of text that match a regular expression.

No equivalent.

REGEXTEST
^^^^^^^^^

Checks whether text matches a regular expression. Only in Excel.

.. code-block:: sql

  -- =REGEXTEST(text, pattern)
  VALUES /*text*/ SIMILAR TO /*pattern, as a SIMILAR TO pattern*/;
  -- =REGEXTEST("Apple", "^[AB]")
  VALUES 'Apple' SIMILAR TO '[AB]%';
  -- COL1: TRUE

The pattern must match the whole text, and ``%`` and ``_`` take the place of
``.*`` and ``.``.

REPLACE
^^^^^^^

Replaces characters at a position in text with other text.

.. code-block:: sql

  -- =REPLACE(old_text, start_num, num_chars, new_text)
  VALUES OVERLAY(/*old_text*/ PLACING /*new_text*/ FROM /*start_num*/ FOR /*num_chars*/);
  -- =REPLACE("Apple", 2, 3, "xx")
  VALUES OVERLAY('Apple' PLACING 'xx' FROM 2 FOR 3);
  -- COL1: Axxe

The ``REPLACE`` function of vsql is a different one, see ``SUBSTITUTE``.

REPLACEB
^^^^^^^^

Replaces bytes at a position in text with other text. Only in Excel.

.. code-block:: sql

  -- =REPLACEB(old_text, start_num, num_bytes, new_text)
  VALUES OVERLAY(/*old_text*/ PLACING /*new_text*/ FROM /*start_num*/ FOR /*num_bytes*/ USING OCTETS);
  -- =REPLACEB("Apple", 2, 3, "xx")
  VALUES OVERLAY('Apple' PLACING 'xx' FROM 2 FOR 3 USING OCTETS);
  -- COL1: Axxe

Bytes are counted in UTF-8, so text that isn't plain ASCII counts differently.

REPT
^^^^

Repeats text a number of times.

.. code-block:: sql

  -- =REPT(text, number_times)
  VALUES REPEAT(/*text*/, /*number_times*/);
  -- =REPT("ab", 3)
  VALUES REPEAT('ab', 3);
  -- COL1: ababab

A negative number of times gives empty text rather than ``#VALUE!``.

RIGHT
^^^^^

Returns the last characters of text.

.. code-block:: sql

  -- =RIGHT(text, num_chars)
  VALUES SUBSTRING(/*text*/ FROM CHAR_LENGTH(/*text*/) - /*num_chars*/ + 1);
  -- =RIGHT("Apple", 2)
  VALUES SUBSTRING('Apple' FROM CHAR_LENGTH('Apple') - 2 + 1);
  -- COL1: le

  -- =RIGHT(text)
  VALUES SUBSTRING(/*text*/ FROM CHAR_LENGTH(/*text*/));
  -- =RIGHT("Apple")
  VALUES SUBSTRING('Apple' FROM CHAR_LENGTH('Apple'));
  -- COL1: e

RIGHTB
^^^^^^

Returns the last bytes of text. Only in Excel.

.. code-block:: sql

  -- =RIGHTB(text, num_bytes)
  VALUES SUBSTRING(/*text*/ FROM OCTET_LENGTH(/*text*/) - /*num_bytes*/ + 1 USING OCTETS);
  -- =RIGHTB("Apple", 2)
  VALUES SUBSTRING('Apple' FROM OCTET_LENGTH('Apple') - 2 + 1 USING OCTETS);
  -- COL1: le

Bytes are counted in UTF-8, so text that isn't plain ASCII counts differently.

SEARCH
^^^^^^

Returns the position of text within other text, ignoring case.

.. code-block:: sql

  -- =SEARCH(find_text, within_text)
  VALUES POSITION(UPPER(/*find_text*/) IN UPPER(/*within_text*/));
  -- =SEARCH("P", "Apple")
  VALUES POSITION(UPPER('P') IN UPPER('Apple'));
  -- COL1: 2

When the text isn't found, the result is 0 rather than ``#VALUE!``. The
wildcards ``?`` and ``*`` aren't supported.

SEARCHB
^^^^^^^

.. code-block:: text

  =SEARCHB(find_text, within_text, [start_num])

Returns the position of text within other text, ignoring case and counted in
bytes. Only in Excel.

No equivalent.

SPLIT
^^^^^

Splits text into separate cells at a delimiter. Only in Google Sheets.

.. code-block:: sql

  -- =INDEX(SPLIT(text, delimiter), 1, column_num)
  VALUES SPLIT_PART(/*text*/, /*delimiter*/, /*column_num*/);
  -- =INDEX(SPLIT("a,b,c", ","), 1, 2)
  VALUES SPLIT_PART('a,b,c', ',', 2);
  -- COL1: b

``SPLIT_PART`` returns one piece at a time, rather than one in each cell. The
whole delimiter is matched, like ``split_by_each`` set to ``FALSE``, and empty
pieces are kept, like ``remove_empty_text`` set to ``FALSE``.

SUBSTITUTE
^^^^^^^^^^

Replaces occurrences of some text with other text.

.. code-block:: sql

  -- =SUBSTITUTE(text, old_text, new_text)
  VALUES REPLACE(/*text*/, /*old_text*/, /*new_text*/);
  -- =SUBSTITUTE("Apple", "p", "b")
  VALUES REPLACE('Apple', 'p', 'b');
  -- COL1: Abble

There's no equivalent of ``instance_num`` to replace only one occurrence, other
than ``TRANSLATE_REGEX`` (F845), which vsql doesn't support yet.

T
^

.. code-block:: text

  =T(value)

Returns a value if it's text, and empty text otherwise.

No equivalent.

TEXT
^^^^

.. code-block:: text

  =TEXT(value, format_text)

Formats a value as text using a number format.

No equivalent.

TEXTAFTER
^^^^^^^^^

Returns the text after a delimiter. Only in Excel.

.. code-block:: sql

  -- =TEXTAFTER(text, delimiter)
  VALUES SUBSTRING(/*text*/ FROM POSITION(/*delimiter*/ IN /*text*/) + CHAR_LENGTH(/*delimiter*/));
  -- =TEXTAFTER("user@example.com", "@")
  VALUES SUBSTRING('user@example.com' FROM POSITION('@' IN 'user@example.com') + CHAR_LENGTH('@'));
  -- COL1: example.com

  -- =TEXTAFTER(text, delimiter, -1)
  VALUES SPLIT_PART(/*text*/, /*delimiter*/, -1);
  -- =TEXTAFTER("www.example.com", ".", -1)
  VALUES SPLIT_PART('www.example.com', '.', -1);
  -- COL1: com

When the delimiter isn't found, the result is part of the text rather than
``#N/A``. The text after the last delimiter (``instance_num`` -1) is the last
piece of ``SPLIT_PART``, which is the whole text when the delimiter isn't
found.

TEXTBEFORE
^^^^^^^^^^

Returns the text before a delimiter. Only in Excel.

.. code-block:: sql

  -- =TEXTBEFORE(text, delimiter)
  VALUES SPLIT_PART(/*text*/, /*delimiter*/, 1);
  -- =TEXTBEFORE("user@example.com", "@")
  VALUES SPLIT_PART('user@example.com', '@', 1);
  -- COL1: user

When the delimiter isn't found, the result is the whole text rather than
``#N/A``. This only works for the first delimiter, because the text before a
later one also has the delimiters before it.

TEXTJOIN
^^^^^^^^

Joins values with a delimiter between them, optionally skipping empty ones.
Only in Excel.

.. code-block:: sql

  -- =TEXTJOIN(delimiter, TRUE, text1)
  SELECT LISTAGG(CAST(/*text1*/ AS VARCHAR(10)), /*delimiter*/) WITHIN GROUP (ORDER BY /*key*/) FROM /*table*/ WHERE /*text1*/ IS NOT NULL;
  -- =TEXTJOIN(", ", TRUE, D2:D5)
  SELECT LISTAGG(CAST(qty AS VARCHAR(10)), ', ') WITHIN GROUP (ORDER BY sku)
  FROM products WHERE qty IS NOT NULL;
  -- COL1: 10, 40, 5

``LISTAGG`` always skips ``NULL``. To keep empty values, use
``COALESCE(x, '')``.

TEXTSPLIT
^^^^^^^^^

Splits text into rows and columns at delimiters. Only in Excel.

.. code-block:: sql

  -- =INDEX(TEXTSPLIT(text, col_delimiter), 1, column_num)
  VALUES SPLIT_PART(/*text*/, /*col_delimiter*/, /*column_num*/);
  -- =INDEX(TEXTSPLIT("a,b,c", ","), 1, 2)
  VALUES SPLIT_PART('a,b,c', ',', 2);
  -- COL1: b

``SPLIT_PART`` returns one piece at a time, rather than one in each cell, and it
can't also split into rows. Empty pieces are kept, and matching is
case-sensitive.

TRANSLATE
^^^^^^^^^

.. code-block:: text

  =TRANSLATE(text, [source_language], [target_language])

Translates text from one language to another. Only in Excel.

No equivalent.

TRIM
^^^^

Removes spaces from the start and end of text.

.. code-block:: sql

  -- =TRIM(text)
  VALUES TRIM(/*text*/);
  -- =TRIM("  Apple  ")
  VALUES TRIM('  Apple  ');
  -- COL1: Apple

A spreadsheet also turns runs of spaces inside the text into one space, which
``TRIM`` doesn't.

UNICHAR
^^^^^^^

Returns the character for a Unicode code point.

.. code-block:: sql

  -- =UNICHAR(number)
  VALUES CHR(/*number*/);
  -- =UNICHAR(8364)
  VALUES CHR(8364);
  -- COL1: €

UNICODE
^^^^^^^

Returns the Unicode code point of the first character of text.

.. code-block:: sql

  -- =UNICODE(text)
  VALUES UNICODE(/*text*/);
  -- =UNICODE("€")
  VALUES UNICODE('€');
  -- COL1: 8364

The code point of empty text is 0 rather than ``#VALUE!``.

UPPER
^^^^^

Changes text to upper case.

.. code-block:: sql

  -- =UPPER(text)
  VALUES UPPER(/*text*/);
  -- =UPPER("Apple")
  VALUES UPPER('Apple');
  -- COL1: APPLE

VALUE
^^^^^

Converts text that looks like a number into a number.

.. code-block:: sql

  -- =VALUE(text)
  VALUES CAST(/*text*/ AS DECIMAL(10, 2));
  -- =VALUE("12.5")
  VALUES CAST('12.5' AS DECIMAL(10, 2));
  -- COL1: 12.50

The text must be a plain number, without currency signs, separators or
percentages.

VALUETOTEXT
^^^^^^^^^^^

Converts a value to text. Only in Excel.

.. code-block:: sql

  -- =VALUETOTEXT(value)
  VALUES CAST(/*value*/ AS VARCHAR(10));
  -- =VALUETOTEXT(12.5)
  VALUES CAST(12.5 AS VARCHAR(10));
  -- COL1: 12.5

Web
---

ENCODEURL
^^^^^^^^^

.. code-block:: text

  =ENCODEURL(text)

Returns text encoded for use in a URL.

No equivalent.

FILTERXML
^^^^^^^^^

.. code-block:: text

  =FILTERXML(xml, xpath)

Returns the parts of an XML document that match an XPath expression. Only in Excel.

No equivalent.

IMPORTCSV
^^^^^^^^^

.. code-block:: text

  =IMPORTCSV(path, [skip_rows], [take_rows], [encoding], [locale])

Imports data from a CSV file. Only in Excel.

No equivalent.

IMPORTDATA
^^^^^^^^^^

.. code-block:: text

  =IMPORTDATA(url, [delimiter], [locale])

Imports a CSV or TSV file from a URL. Only in Google Sheets.

No equivalent.

IMPORTFEED
^^^^^^^^^^

.. code-block:: text

  =IMPORTFEED(url, [query], [headers], [num_items])

Imports an RSS or Atom feed. Only in Google Sheets.

No equivalent.

IMPORTHTML
^^^^^^^^^^

.. code-block:: text

  =IMPORTHTML(url, query, index, [locale])

Imports a table or list from a web page. Only in Google Sheets.

No equivalent.

IMPORTRANGE
^^^^^^^^^^^

.. code-block:: text

  =IMPORTRANGE(spreadsheet_url, range_string)

Imports a range from another spreadsheet. Only in Google Sheets.

No equivalent.

IMPORTTEXT
^^^^^^^^^^

.. code-block:: text

  =IMPORTTEXT(path, [delimiter], [skip_rows], [take_rows], [encoding], [locale])

Imports data from a delimited text file. Only in Excel.

No equivalent.

IMPORTXML
^^^^^^^^^

.. code-block:: text

  =IMPORTXML(url, xpath_query, [locale])

Imports data from a web page or XML file using an XPath query. Only in Google Sheets.

No equivalent.

WEBSERVICE
^^^^^^^^^^

.. code-block:: text

  =WEBSERVICE(url)

Returns the response from a web service. Only in Excel.

No equivalent.
