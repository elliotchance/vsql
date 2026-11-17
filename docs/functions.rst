Functions
=========

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
   functions-conditional.rst
   functions-date-and-time.rst
   functions-error-and-gamma.rst
   functions-exponent-and-logarithm.rst
   functions-random.rst
   functions-rounding.rst
   functions-session.rst
   functions-statistical.rst
   functions-string.rst
   functions-trigonometric.rst

Every function:

.. list-table::
   :header-rows: 1

   * - Function
     - Category
     - SQL standard

   * - :ref:`ABS <functions-arithmetic:ABS>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - T441
   * - :ref:`ACOS <functions-trigonometric:ACOS>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`ANY <functions-aggregate:ANY>`
     - :doc:`Aggregate <functions-aggregate>`
     - T031
   * - :ref:`ANY_VALUE <functions-aggregate:ANY_VALUE>`
     - :doc:`Aggregate <functions-aggregate>`
     - T626
   * - :ref:`ASIN <functions-trigonometric:ASIN>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`ATAN <functions-trigonometric:ATAN>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`ATAN2 <functions-trigonometric:ATAN2>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`AVG <functions-aggregate:AVG>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-01)
   * - :ref:`BTRIM <functions-string:BTRIM>`
     - :doc:`String <functions-string>`
     - T056
   * - :ref:`CBRT <functions-exponent-and-logarithm:CBRT>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - Not standard
   * - :ref:`CEIL <functions-rounding:CEIL>`
     - :doc:`Rounding <functions-rounding>`
     - T621
   * - :ref:`CEILING <functions-rounding:CEILING>`
     - :doc:`Rounding <functions-rounding>`
     - T621
   * - :ref:`CHARACTER_LENGTH <functions-string:CHARACTER_LENGTH>`
     - :doc:`String <functions-string>`
     - Core (E021-04)
   * - :ref:`CHAR_LENGTH <functions-string:CHAR_LENGTH>`
     - :doc:`String <functions-string>`
     - Core (E021-04)
   * - :ref:`CHR <functions-string:CHR>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`COALESCE <functions-conditional:COALESCE>`
     - :doc:`Conditional <functions-conditional>`
     - Core (F261-04)
   * - :ref:`CORR <functions-statistical:CORR>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`COS <functions-trigonometric:COS>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`COSH <functions-trigonometric:COSH>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`COUNT <functions-aggregate:COUNT>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-02)
   * - :ref:`COVAR_POP <functions-statistical:COVAR_POP>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`COVAR_SAMP <functions-statistical:COVAR_SAMP>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`CUME_DIST <functions-aggregate:CUME_DIST>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`CURRENT_CATALOG <functions-session:CURRENT_CATALOG>`
     - :doc:`Session <functions-session>`
     - F762
   * - :ref:`CURRENT_DATE <functions-date-and-time:CURRENT_DATE>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Core (F051-06)
   * - :ref:`CURRENT_SCHEMA <functions-session:CURRENT_SCHEMA>`
     - :doc:`Session <functions-session>`
     - F763
   * - :ref:`CURRENT_TIME <functions-date-and-time:CURRENT_TIME>`
     - :doc:`Date and Time <functions-date-and-time>`
     - F411
   * - :ref:`CURRENT_TIMESTAMP <functions-date-and-time:CURRENT_TIMESTAMP>`
     - :doc:`Date and Time <functions-date-and-time>`
     - F411
   * - :ref:`DEGREES <functions-trigonometric:DEGREES>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`DENSE_RANK <functions-aggregate:DENSE_RANK>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`ERF <functions-error-and-gamma:ERF>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`ERFC <functions-error-and-gamma:ERFC>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`EVERY <functions-aggregate:EVERY>`
     - :doc:`Aggregate <functions-aggregate>`
     - T031
   * - :ref:`EXP <functions-exponent-and-logarithm:EXP>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`EXTRACT <functions-date-and-time:EXTRACT>`
     - :doc:`Date and Time <functions-date-and-time>`
     - F052
   * - :ref:`FACTORIAL <functions-arithmetic:FACTORIAL>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`FLOOR <functions-rounding:FLOOR>`
     - :doc:`Rounding <functions-rounding>`
     - T621
   * - :ref:`GAMMA <functions-error-and-gamma:GAMMA>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`GCD <functions-arithmetic:GCD>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`GREATEST <functions-conditional:GREATEST>`
     - :doc:`Conditional <functions-conditional>`
     - T054
   * - :ref:`INITCAP <functions-string:INITCAP>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`LCM <functions-arithmetic:LCM>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`LEAST <functions-conditional:LEAST>`
     - :doc:`Conditional <functions-conditional>`
     - T054
   * - :ref:`LGAMMA <functions-error-and-gamma:LGAMMA>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`LISTAGG <functions-aggregate:LISTAGG>`
     - :doc:`Aggregate <functions-aggregate>`
     - T625
   * - :ref:`LN <functions-exponent-and-logarithm:LN>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`LOCALTIME <functions-date-and-time:LOCALTIME>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Core (F051-07)
   * - :ref:`LOCALTIMESTAMP <functions-date-and-time:LOCALTIMESTAMP>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Core (F051-08)
   * - :ref:`LOG <functions-exponent-and-logarithm:LOG>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T623
   * - :ref:`LOG10 <functions-exponent-and-logarithm:LOG10>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T624
   * - :ref:`LOWER <functions-string:LOWER>`
     - :doc:`String <functions-string>`
     - Core (E021-08)
   * - :ref:`LPAD <functions-string:LPAD>`
     - :doc:`String <functions-string>`
     - T055
   * - :ref:`LTRIM <functions-string:LTRIM>`
     - :doc:`String <functions-string>`
     - T056
   * - :ref:`MAX <functions-aggregate:MAX>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-03)
   * - :ref:`MIN <functions-aggregate:MIN>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-04)
   * - :ref:`MOD <functions-arithmetic:MOD>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - T441
   * - :ref:`MODE <functions-aggregate:MODE>`
     - :doc:`Aggregate <functions-aggregate>`
     - Not standard
   * - :ref:`NOW <functions-date-and-time:NOW>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Not standard
   * - :ref:`NULLIF <functions-conditional:NULLIF>`
     - :doc:`Conditional <functions-conditional>`
     - Core (F261-03)
   * - :ref:`OCTET_LENGTH <functions-string:OCTET_LENGTH>`
     - :doc:`String <functions-string>`
     - Core (E021-05)
   * - :ref:`OVERLAY <functions-string:OVERLAY>`
     - :doc:`String <functions-string>`
     - T312
   * - :ref:`PERCENTILE_CONT <functions-aggregate:PERCENTILE_CONT>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`PERCENTILE_DISC <functions-aggregate:PERCENTILE_DISC>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`PERCENT_RANK <functions-aggregate:PERCENT_RANK>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`PI <functions-trigonometric:PI>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`POSITION <functions-string:POSITION>`
     - :doc:`String <functions-string>`
     - Core (E021-11)
   * - :ref:`POWER <functions-exponent-and-logarithm:POWER>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`PRODUCT <functions-aggregate:PRODUCT>`
     - :doc:`Aggregate <functions-aggregate>`
     - Not standard
   * - :ref:`RADIANS <functions-trigonometric:RADIANS>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`RANDOM <functions-random:RANDOM>`
     - :doc:`Random <functions-random>`
     - Not standard
   * - :ref:`RANK <functions-aggregate:RANK>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`REGR_AVGX <functions-statistical:REGR_AVGX>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_AVGY <functions-statistical:REGR_AVGY>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_COUNT <functions-statistical:REGR_COUNT>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_INTERCEPT <functions-statistical:REGR_INTERCEPT>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_R2 <functions-statistical:REGR_R2>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SLOPE <functions-statistical:REGR_SLOPE>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SXX <functions-statistical:REGR_SXX>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SXY <functions-statistical:REGR_SXY>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SYY <functions-statistical:REGR_SYY>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REPEAT <functions-string:REPEAT>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`REPLACE <functions-string:REPLACE>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`ROUND <functions-rounding:ROUND>`
     - :doc:`Rounding <functions-rounding>`
     - Not standard
   * - :ref:`RPAD <functions-string:RPAD>`
     - :doc:`String <functions-string>`
     - T055
   * - :ref:`RTRIM <functions-string:RTRIM>`
     - :doc:`String <functions-string>`
     - T056
   * - :ref:`SIGN <functions-arithmetic:SIGN>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`SIN <functions-trigonometric:SIN>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`SINH <functions-trigonometric:SINH>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`SOME <functions-aggregate:SOME>`
     - :doc:`Aggregate <functions-aggregate>`
     - T031
   * - :ref:`SPLIT_PART <functions-string:SPLIT_PART>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`SQRT <functions-exponent-and-logarithm:SQRT>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`STDDEV_POP <functions-statistical:STDDEV_POP>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`STDDEV_SAMP <functions-statistical:STDDEV_SAMP>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`SUBSTRING <functions-string:SUBSTRING>`
     - :doc:`String <functions-string>`
     - Core (E021-06), T581
   * - :ref:`SUM <functions-aggregate:SUM>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-05)
   * - :ref:`TAN <functions-trigonometric:TAN>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`TANH <functions-trigonometric:TANH>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`TRIM <functions-string:TRIM>`
     - :doc:`String <functions-string>`
     - Core (E021-09)
   * - :ref:`TRUNC <functions-rounding:TRUNC>`
     - :doc:`Rounding <functions-rounding>`
     - Not standard
   * - :ref:`UNICODE <functions-string:UNICODE>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`UPPER <functions-string:UPPER>`
     - :doc:`String <functions-string>`
     - Core (E021-08)
   * - :ref:`VAR_POP <functions-statistical:VAR_POP>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`VAR_SAMP <functions-statistical:VAR_SAMP>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`WIDTH_BUCKET <functions-arithmetic:WIDTH_BUCKET>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - T612
