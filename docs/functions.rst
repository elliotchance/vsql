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

   * - :ref:`ABS <function-abs>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - T441
   * - :ref:`ACOS <function-acos>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`ANY <function-any>`
     - :doc:`Aggregate <functions-aggregate>`
     - T031
   * - :ref:`ANY_VALUE <function-any_value>`
     - :doc:`Aggregate <functions-aggregate>`
     - T626
   * - :ref:`ASIN <function-asin>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`ATAN <function-atan>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`ATAN2 <function-atan2>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`AVG <function-avg>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-01)
   * - :ref:`BTRIM <function-btrim>`
     - :doc:`String <functions-string>`
     - T056
   * - :ref:`CBRT <function-cbrt>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - Not standard
   * - :ref:`CEIL <function-ceil>`
     - :doc:`Rounding <functions-rounding>`
     - T621
   * - :ref:`CEILING <function-ceiling>`
     - :doc:`Rounding <functions-rounding>`
     - T621
   * - :ref:`CHARACTER_LENGTH <function-character_length>`
     - :doc:`String <functions-string>`
     - Core (E021-04)
   * - :ref:`CHAR_LENGTH <function-char_length>`
     - :doc:`String <functions-string>`
     - Core (E021-04)
   * - :ref:`CHR <function-chr>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`COALESCE <function-coalesce>`
     - :doc:`Conditional <functions-conditional>`
     - Core (F261-04)
   * - :ref:`CORR <function-corr>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`COS <function-cos>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`COSH <function-cosh>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`COUNT <function-count>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-02)
   * - :ref:`COVAR_POP <function-covar_pop>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`COVAR_SAMP <function-covar_samp>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`CUME_DIST <function-cume_dist>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`CURRENT_CATALOG <function-current_catalog>`
     - :doc:`Session <functions-session>`
     - F762
   * - :ref:`CURRENT_DATE <function-current_date>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Core (F051-06)
   * - :ref:`CURRENT_SCHEMA <function-current_schema>`
     - :doc:`Session <functions-session>`
     - F763
   * - :ref:`CURRENT_TIME <function-current_time>`
     - :doc:`Date and Time <functions-date-and-time>`
     - F411
   * - :ref:`CURRENT_TIMESTAMP <function-current_timestamp>`
     - :doc:`Date and Time <functions-date-and-time>`
     - F411
   * - :ref:`DEGREES <function-degrees>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`DENSE_RANK <function-dense_rank>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`ERF <function-erf>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`ERFC <function-erfc>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`EVERY <function-every>`
     - :doc:`Aggregate <functions-aggregate>`
     - T031
   * - :ref:`EXP <function-exp>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`EXTRACT <function-extract>`
     - :doc:`Date and Time <functions-date-and-time>`
     - F052
   * - :ref:`FACTORIAL <function-factorial>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`FLOOR <function-floor>`
     - :doc:`Rounding <functions-rounding>`
     - T621
   * - :ref:`GAMMA <function-gamma>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`GCD <function-gcd>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`GREATEST <function-greatest>`
     - :doc:`Conditional <functions-conditional>`
     - T054
   * - :ref:`INITCAP <function-initcap>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`LCM <function-lcm>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`LEAST <function-least>`
     - :doc:`Conditional <functions-conditional>`
     - T054
   * - :ref:`LGAMMA <function-lgamma>`
     - :doc:`Error and Gamma <functions-error-and-gamma>`
     - Not standard
   * - :ref:`LISTAGG <function-listagg>`
     - :doc:`Aggregate <functions-aggregate>`
     - T625
   * - :ref:`LN <function-ln>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`LOCALTIME <function-localtime>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Core (F051-07)
   * - :ref:`LOCALTIMESTAMP <function-localtimestamp>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Core (F051-08)
   * - :ref:`LOG <function-log>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T623
   * - :ref:`LOG10 <function-log10>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T624
   * - :ref:`LOWER <function-lower>`
     - :doc:`String <functions-string>`
     - Core (E021-08)
   * - :ref:`LPAD <function-lpad>`
     - :doc:`String <functions-string>`
     - T055
   * - :ref:`LTRIM <function-ltrim>`
     - :doc:`String <functions-string>`
     - T056
   * - :ref:`MAX <function-max>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-03)
   * - :ref:`MIN <function-min>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-04)
   * - :ref:`MOD <function-mod>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - T441
   * - :ref:`MODE <function-mode>`
     - :doc:`Aggregate <functions-aggregate>`
     - Not standard
   * - :ref:`NOW <function-now>`
     - :doc:`Date and Time <functions-date-and-time>`
     - Not standard
   * - :ref:`NULLIF <function-nullif>`
     - :doc:`Conditional <functions-conditional>`
     - Core (F261-03)
   * - :ref:`OCTET_LENGTH <function-octet_length>`
     - :doc:`String <functions-string>`
     - Core (E021-05)
   * - :ref:`OVERLAY <function-overlay>`
     - :doc:`String <functions-string>`
     - T312
   * - :ref:`PERCENTILE_CONT <function-percentile_cont>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`PERCENTILE_DISC <function-percentile_disc>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`PERCENT_RANK <function-percent_rank>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`PI <function-pi>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`POSITION <function-position>`
     - :doc:`String <functions-string>`
     - Core (E021-11)
   * - :ref:`POWER <function-power>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`PRODUCT <function-product>`
     - :doc:`Aggregate <functions-aggregate>`
     - Not standard
   * - :ref:`RADIANS <function-radians>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - Not standard
   * - :ref:`RANDOM <function-random>`
     - :doc:`Random <functions-random>`
     - Not standard
   * - :ref:`RANK <function-rank>`
     - :doc:`Aggregate <functions-aggregate>`
     - T612
   * - :ref:`REGR_AVGX <function-regr_avgx>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_AVGY <function-regr_avgy>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_COUNT <function-regr_count>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_INTERCEPT <function-regr_intercept>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_R2 <function-regr_r2>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SLOPE <function-regr_slope>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SXX <function-regr_sxx>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SXY <function-regr_sxy>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REGR_SYY <function-regr_syy>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`REPEAT <function-repeat>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`REPLACE <function-replace>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`ROUND <function-round>`
     - :doc:`Rounding <functions-rounding>`
     - Not standard
   * - :ref:`RPAD <function-rpad>`
     - :doc:`String <functions-string>`
     - T055
   * - :ref:`RTRIM <function-rtrim>`
     - :doc:`String <functions-string>`
     - T056
   * - :ref:`SIGN <function-sign>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - Not standard
   * - :ref:`SIN <function-sin>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`SINH <function-sinh>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`SOME <function-some>`
     - :doc:`Aggregate <functions-aggregate>`
     - T031
   * - :ref:`SPLIT_PART <function-split_part>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`SQRT <function-sqrt>`
     - :doc:`Exponent and Logarithm <functions-exponent-and-logarithm>`
     - T621
   * - :ref:`STDDEV_POP <function-stddev_pop>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`STDDEV_SAMP <function-stddev_samp>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`SUBSTRING <function-substring>`
     - :doc:`String <functions-string>`
     - Core (E021-06), T581
   * - :ref:`SUM <function-sum>`
     - :doc:`Aggregate <functions-aggregate>`
     - Core (E091-05)
   * - :ref:`TAN <function-tan>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`TANH <function-tanh>`
     - :doc:`Trigonometric <functions-trigonometric>`
     - T622
   * - :ref:`TRIM <function-trim>`
     - :doc:`String <functions-string>`
     - Core (E021-09)
   * - :ref:`TRUNC <function-trunc>`
     - :doc:`Rounding <functions-rounding>`
     - Not standard
   * - :ref:`UNICODE <function-unicode>`
     - :doc:`String <functions-string>`
     - Not standard
   * - :ref:`UPPER <function-upper>`
     - :doc:`String <functions-string>`
     - Core (E021-08)
   * - :ref:`VAR_POP <function-var_pop>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`VAR_SAMP <function-var_samp>`
     - :doc:`Statistical <functions-statistical>`
     - T621
   * - :ref:`WIDTH_BUCKET <function-width_bucket>`
     - :doc:`Arithmetic <functions-arithmetic>`
     - T612
