Functions
=========

Every function of vsql is in :doc:`functions`, with the types it accepts, what
it returns and how it compares to the SQL standard and other databases.

If you know the functions of another database or of a spreadsheet,
:doc:`compatibility` shows how to write each of them in vsql.

Functions that aren't built in can be added with :doc:`custom-functions`.

.. toctree::
   :maxdepth: 2

   functions.rst
   compatibility.rst

Function Index
--------------

Every function, in alphabetical order:

.. list-table::
   :header-rows: 1
   :widths: 25 50 25

   * - Function
     - Description
     - Category
   * - :ref:`ABS <functions-arithmetic:ABS>`
     - Absolute value
     - Arithmetic
   * - :ref:`ACOS <functions-trigonometric:ACOS>`
     - Inverse (arc) cosine
     - Trigonometric
   * - :ref:`ANY <functions-aggregate:ANY>`
     - ``TRUE`` if any value is ``TRUE``
     - Aggregate
   * - :ref:`ANY_VALUE <functions-aggregate:ANY_VALUE>`
     - Any one value of the group
     - Aggregate
   * - :ref:`ASIN <functions-trigonometric:ASIN>`
     - Inverse (arc) sine
     - Trigonometric
   * - :ref:`ATAN <functions-trigonometric:ATAN>`
     - Inverse (arc) tangent
     - Trigonometric
   * - :ref:`ATAN2 <functions-trigonometric:ATAN2>`
     - Angle of the point (X, Y) from the x axis
     - Trigonometric
   * - :ref:`AVG <functions-aggregate:AVG>`
     - Average value
     - Aggregate
   * - :ref:`BASE64_TO_BINARY <functions-string:BASE64_TO_BINARY>`
     - Convert base64 text to a binary string
     - String
   * - :ref:`BINARY_TO_BASE64 <functions-string:BINARY_TO_BASE64>`
     - Convert a binary string to base64 text
     - String
   * - :ref:`BINARY_TO_HEX <functions-string:BINARY_TO_HEX>`
     - Convert a binary string to hexadecimal digits
     - String
   * - :ref:`BINARY_TO_UUID <functions-uuid:BINARY_TO_UUID>`
     - Convert 16 octets to a UUID string
     - UUID
   * - :ref:`BIT_AND <functions-aggregate:BIT_AND>`
     - Bitwise AND of the values
     - Aggregate
   * - :ref:`BIT_OR <functions-aggregate:BIT_OR>`
     - Bitwise OR of the values
     - Aggregate
   * - :ref:`BIT_XOR <functions-aggregate:BIT_XOR>`
     - Bitwise exclusive OR of the values
     - Aggregate
   * - :ref:`BTRIM <functions-string:BTRIM>`
     - Remove characters from both ends of a string
     - String
   * - :ref:`BUILD_COMMIT <functions-build:BUILD_COMMIT>`
     - Git commit of the vsql release
     - Build
   * - :ref:`BUILD_C_COMPILER <functions-build:BUILD_C_COMPILER>`
     - C compiler that compiled vsql
     - Build
   * - :ref:`BUILD_DATE <functions-build:BUILD_DATE>`
     - Date that vsql was compiled
     - Build
   * - :ref:`BUILD_VERSION <functions-build:BUILD_VERSION>`
     - Release of vsql
     - Build
   * - :ref:`BUILD_V_COMMIT <functions-build:BUILD_V_COMMIT>`
     - Commit of the V compiler
     - Build
   * - :ref:`BUILD_V_VERSION <functions-build:BUILD_V_VERSION>`
     - Version of the V compiler
     - Build
   * - :ref:`CBRT <functions-exponent-and-logarithm:CBRT>`
     - Cube root
     - Exponent and Logarithm
   * - :ref:`CEIL <functions-rounding:CEIL>`
     - Round up to an integer
     - Rounding
   * - :ref:`CEILING <functions-rounding:CEILING>`
     - Same as ``CEIL``
     - Rounding
   * - :ref:`CHARACTER_LENGTH <functions-string:CHARACTER_LENGTH>`
     - Same as ``CHAR_LENGTH``
     - String
   * - :ref:`CHAR_LENGTH <functions-string:CHAR_LENGTH>`
     - Number of characters in a string
     - String
   * - :ref:`CHR <functions-string:CHR>`
     - Character with a Unicode code point
     - String
   * - :ref:`COALESCE <functions-conditional:COALESCE>`
     - First value that isn't ``NULL``
     - Conditional
   * - :ref:`CONCAT <functions-string:CONCAT>`
     - Join strings, skipping ``NULL``
     - String
   * - :ref:`CONCAT_WS <functions-string:CONCAT_WS>`
     - Join strings with a separator, skipping ``NULL``
     - String
   * - :ref:`CORR <functions-statistical:CORR>`
     - Correlation coefficient
     - Statistical
   * - :ref:`COS <functions-trigonometric:COS>`
     - Cosine
     - Trigonometric
   * - :ref:`COSH <functions-trigonometric:COSH>`
     - Hyperbolic cosine
     - Trigonometric
   * - :ref:`COUNT <functions-aggregate:COUNT>`
     - Number of rows or values
     - Aggregate
   * - :ref:`COVAR_POP <functions-statistical:COVAR_POP>`
     - Population covariance
     - Statistical
   * - :ref:`COVAR_SAMP <functions-statistical:COVAR_SAMP>`
     - Sample covariance
     - Statistical
   * - :ref:`CUME_DIST <functions-aggregate:CUME_DIST>`
     - Cumulative distribution of a hypothetical row
     - Aggregate
   * - :ref:`CURRENT_CATALOG <functions-session:CURRENT_CATALOG>`
     - Name of the current catalog
     - Session
   * - :ref:`CURRENT_DATE <functions-date-and-time:CURRENT_DATE>`
     - Current date
     - Date and Time
   * - :ref:`CURRENT_SCHEMA <functions-session:CURRENT_SCHEMA>`
     - Name of the current schema
     - Session
   * - :ref:`CURRENT_TIME <functions-date-and-time:CURRENT_TIME>`
     - Current time with the time zone
     - Date and Time
   * - :ref:`CURRENT_TIMESTAMP <functions-date-and-time:CURRENT_TIMESTAMP>`
     - Current date and time with the time zone
     - Date and Time
   * - :ref:`DATE_TRUNC <functions-date-and-time:DATE_TRUNC>`
     - Round a datetime down to the start of a unit
     - Date and Time
   * - :ref:`DEGREES <functions-trigonometric:DEGREES>`
     - Radians to degrees
     - Trigonometric
   * - :ref:`DENSE_RANK <functions-aggregate:DENSE_RANK>`
     - Rank of a hypothetical row, without gaps
     - Aggregate
   * - :ref:`ENDS_WITH <functions-string:ENDS_WITH>`
     - Whether a string ends with a suffix
     - String
   * - :ref:`ERF <functions-error-and-gamma:ERF>`
     - Error function
     - Error and Gamma
   * - :ref:`ERFC <functions-error-and-gamma:ERFC>`
     - Complementary error function
     - Error and Gamma
   * - :ref:`EVERY <functions-aggregate:EVERY>`
     - ``TRUE`` if every value is ``TRUE``
     - Aggregate
   * - :ref:`EXP <functions-exponent-and-logarithm:EXP>`
     - *e* raised to a power
     - Exponent and Logarithm
   * - :ref:`EXTRACT <functions-date-and-time:EXTRACT>`
     - One field of a datetime
     - Date and Time
   * - :ref:`FACTORIAL <functions-arithmetic:FACTORIAL>`
     - Factorial of an integer
     - Arithmetic
   * - :ref:`FLOOR <functions-rounding:FLOOR>`
     - Round down to an integer
     - Rounding
   * - :ref:`FORMAT_SIZE <functions-string:FORMAT_SIZE>`
     - Format a number of bytes as a size
     - String
   * - :ref:`GAMMA <functions-error-and-gamma:GAMMA>`
     - Gamma function
     - Error and Gamma
   * - :ref:`GCD <functions-arithmetic:GCD>`
     - Greatest common divisor
     - Arithmetic
   * - :ref:`GENERATE_UUID_V4 <functions-uuid:GENERATE_UUID_V4>`
     - Generate a random (version 4) UUID
     - UUID
   * - :ref:`GENERATE_UUID_V7 <functions-uuid:GENERATE_UUID_V7>`
     - Generate a time-ordered (version 7) UUID
     - UUID
   * - :ref:`GREATEST <functions-conditional:GREATEST>`
     - Greatest of the values
     - Conditional
   * - :ref:`HEX_TO_BINARY <functions-string:HEX_TO_BINARY>`
     - Convert hexadecimal digits to a binary string
     - String
   * - :ref:`IF <functions-conditional:IF>`
     - One value if a condition is true, otherwise another
     - Conditional
   * - :ref:`INITCAP <functions-string:INITCAP>`
     - Capitalize the first letter of each word
     - String
   * - :ref:`LAST_DAY <functions-date-and-time:LAST_DAY>`
     - Last day of the month of a date
     - Date and Time
   * - :ref:`LCM <functions-arithmetic:LCM>`
     - Least common multiple
     - Arithmetic
   * - :ref:`LEAST <functions-conditional:LEAST>`
     - Least of the values
     - Conditional
   * - :ref:`LEFT <functions-string:LEFT>`
     - First characters or octets of a string
     - String
   * - :ref:`LENGTH <functions-string:LENGTH>`
     - Same as ``CHAR_LENGTH``
     - String
   * - :ref:`LGAMMA <functions-error-and-gamma:LGAMMA>`
     - Natural logarithm of the gamma function
     - Error and Gamma
   * - :ref:`LISTAGG <functions-aggregate:LISTAGG>`
     - Join the group's strings into one
     - Aggregate
   * - :ref:`LN <functions-exponent-and-logarithm:LN>`
     - Natural logarithm
     - Exponent and Logarithm
   * - :ref:`LOCALTIME <functions-date-and-time:LOCALTIME>`
     - Current time without a time zone
     - Date and Time
   * - :ref:`LOCALTIMESTAMP <functions-date-and-time:LOCALTIMESTAMP>`
     - Current date and time without a time zone
     - Date and Time
   * - :ref:`LOG <functions-exponent-and-logarithm:LOG>`
     - Logarithm in any base
     - Exponent and Logarithm
   * - :ref:`LOG10 <functions-exponent-and-logarithm:LOG10>`
     - Logarithm in base 10
     - Exponent and Logarithm
   * - :ref:`LOWER <functions-string:LOWER>`
     - Convert a string to lower case
     - String
   * - :ref:`LPAD <functions-string:LPAD>`
     - Pad the start of a string
     - String
   * - :ref:`LTRIM <functions-string:LTRIM>`
     - Remove characters from the start of a string
     - String
   * - :ref:`MAKE_DATE <functions-date-and-time:MAKE_DATE>`
     - Date from its year, month and day
     - Date and Time
   * - :ref:`MAKE_INTERVAL <functions-date-and-time:MAKE_INTERVAL>`
     - Build an interval from numbers
     - Date and Time
   * - :ref:`MAKE_TIME <functions-date-and-time:MAKE_TIME>`
     - Time from its hour, minute and second
     - Date and Time
   * - :ref:`MAKE_TIMESTAMP <functions-date-and-time:MAKE_TIMESTAMP>`
     - Timestamp from its fields
     - Date and Time
   * - :ref:`MAKE_TIMESTAMPTZ <functions-date-and-time:MAKE_TIMESTAMPTZ>`
     - Timestamp with a time zone from its fields
     - Date and Time
   * - :ref:`MAX <functions-aggregate:MAX>`
     - Maximum value
     - Aggregate
   * - :ref:`MEDIAN <functions-aggregate:MEDIAN>`
     - Middle value
     - Aggregate
   * - :ref:`MIN <functions-aggregate:MIN>`
     - Minimum value
     - Aggregate
   * - :ref:`MIN_SCALE <functions-rounding:MIN_SCALE>`
     - Fewest decimal places a number needs
     - Rounding
   * - :ref:`MOD <functions-arithmetic:MOD>`
     - Remainder of a division
     - Arithmetic
   * - :ref:`MODE <functions-aggregate:MODE>`
     - Most frequent value
     - Aggregate
   * - :ref:`NOW <functions-date-and-time:NOW>`
     - Wall clock time when it's called
     - Date and Time
   * - :ref:`NULLIF <functions-conditional:NULLIF>`
     - ``NULL`` if two values are equal
     - Conditional
   * - :ref:`OCTET_LENGTH <functions-string:OCTET_LENGTH>`
     - Length of a string in bytes
     - String
   * - :ref:`OVERLAY <functions-string:OVERLAY>`
     - Replace part of a string
     - String
   * - :ref:`PARSE_SIZE <functions-string:PARSE_SIZE>`
     - Convert a size to a number of bytes
     - String
   * - :ref:`PERCENTILE_CONT <functions-aggregate:PERCENTILE_CONT>`
     - Interpolated value at a fraction of the sorted values
     - Aggregate
   * - :ref:`PERCENTILE_DISC <functions-aggregate:PERCENTILE_DISC>`
     - Value at a fraction of the sorted values
     - Aggregate
   * - :ref:`PERCENT_RANK <functions-aggregate:PERCENT_RANK>`
     - Relative rank of a hypothetical row
     - Aggregate
   * - :ref:`PI <functions-trigonometric:PI>`
     - The constant π
     - Trigonometric
   * - :ref:`POSITION <functions-string:POSITION>`
     - Where a string first appears in another
     - String
   * - :ref:`POWER <functions-exponent-and-logarithm:POWER>`
     - A number raised to a power
     - Exponent and Logarithm
   * - :ref:`PRODUCT <functions-aggregate:PRODUCT>`
     - Every value multiplied together
     - Aggregate
   * - :ref:`QUOTE <functions-string:QUOTE>`
     - An SQL literal for a value
     - String
   * - :ref:`QUOTE_IDENT <functions-string:QUOTE_IDENT>`
     - A delimited identifier for a name
     - String
   * - :ref:`RADIANS <functions-trigonometric:RADIANS>`
     - Degrees to radians
     - Trigonometric
   * - :ref:`RANDOM <functions-random:RANDOM>`
     - Random number from 0 to less than 1, or in a range
     - Random
   * - :ref:`RANDOM_BINARY <functions-random:RANDOM_BINARY>`
     - Random bytes
     - Random
   * - :ref:`RANDOM_NORMAL <functions-random:RANDOM_NORMAL>`
     - Normally distributed random number
     - Random
   * - :ref:`RANK <functions-aggregate:RANK>`
     - Rank of a hypothetical row
     - Aggregate
   * - :ref:`REGR_AVGX <functions-statistical:REGR_AVGX>`
     - Average of X
     - Statistical
   * - :ref:`REGR_AVGY <functions-statistical:REGR_AVGY>`
     - Average of Y
     - Statistical
   * - :ref:`REGR_COUNT <functions-statistical:REGR_COUNT>`
     - Number of rows where X and Y aren't ``NULL``
     - Statistical
   * - :ref:`REGR_INTERCEPT <functions-statistical:REGR_INTERCEPT>`
     - Y intercept of the least-squares line
     - Statistical
   * - :ref:`REGR_R2 <functions-statistical:REGR_R2>`
     - Coefficient of determination
     - Statistical
   * - :ref:`REGR_SLOPE <functions-statistical:REGR_SLOPE>`
     - Slope of the least-squares line
     - Statistical
   * - :ref:`REGR_SXX <functions-statistical:REGR_SXX>`
     - Sum of squares of X
     - Statistical
   * - :ref:`REGR_SXY <functions-statistical:REGR_SXY>`
     - Sum of products of X and Y
     - Statistical
   * - :ref:`REGR_SYY <functions-statistical:REGR_SYY>`
     - Sum of squares of Y
     - Statistical
   * - :ref:`REPEAT <functions-string:REPEAT>`
     - Repeat a string
     - String
   * - :ref:`REPLACE <functions-string:REPLACE>`
     - Replace every occurrence in a string
     - String
   * - :ref:`REVERSE <functions-string:REVERSE>`
     - Characters or octets in the opposite order
     - String
   * - :ref:`RIGHT <functions-string:RIGHT>`
     - Last characters or octets of a string
     - String
   * - :ref:`ROUND <functions-rounding:ROUND>`
     - Round to the nearest integer or decimal place
     - Rounding
   * - :ref:`RPAD <functions-string:RPAD>`
     - Pad the end of a string
     - String
   * - :ref:`RTRIM <functions-string:RTRIM>`
     - Remove characters from the end of a string
     - String
   * - :ref:`SIGN <functions-arithmetic:SIGN>`
     - Sign of a number: -1, 0 or 1
     - Arithmetic
   * - :ref:`SIN <functions-trigonometric:SIN>`
     - Sine
     - Trigonometric
   * - :ref:`SINH <functions-trigonometric:SINH>`
     - Hyperbolic sine
     - Trigonometric
   * - :ref:`SOME <functions-aggregate:SOME>`
     - Same as ``ANY``
     - Aggregate
   * - :ref:`SPLIT_PART <functions-string:SPLIT_PART>`
     - Nth part of a string split on a delimiter
     - String
   * - :ref:`SQRT <functions-exponent-and-logarithm:SQRT>`
     - Square root
     - Exponent and Logarithm
   * - :ref:`STARTS_WITH <functions-string:STARTS_WITH>`
     - Whether a string starts with a prefix
     - String
   * - :ref:`STDDEV_POP <functions-statistical:STDDEV_POP>`
     - Population standard deviation
     - Statistical
   * - :ref:`STDDEV_SAMP <functions-statistical:STDDEV_SAMP>`
     - Sample standard deviation
     - Statistical
   * - :ref:`SUBSTRING <functions-string:SUBSTRING>`
     - Part of a string
     - String
   * - :ref:`SUM <functions-aggregate:SUM>`
     - Sum of the values
     - Aggregate
   * - :ref:`TAN <functions-trigonometric:TAN>`
     - Tangent
     - Trigonometric
   * - :ref:`TANH <functions-trigonometric:TANH>`
     - Hyperbolic tangent
     - Trigonometric
   * - :ref:`TRIM <functions-string:TRIM>`
     - Remove a character from the ends of a string
     - String
   * - :ref:`TRIM_SCALE <functions-rounding:TRIM_SCALE>`
     - Number without trailing zero decimal places
     - Rounding
   * - :ref:`TRUNC <functions-rounding:TRUNC>`
     - Truncate towards zero
     - Rounding
   * - :ref:`UNICODE <functions-string:UNICODE>`
     - Unicode code point of a character
     - String
   * - :ref:`UPPER <functions-string:UPPER>`
     - Convert a string to upper case
     - String
   * - :ref:`UUID_TO_BINARY <functions-uuid:UUID_TO_BINARY>`
     - Convert a UUID string to 16 octets
     - UUID
   * - :ref:`VAR_POP <functions-statistical:VAR_POP>`
     - Population variance
     - Statistical
   * - :ref:`VAR_SAMP <functions-statistical:VAR_SAMP>`
     - Sample variance
     - Statistical
   * - :ref:`WIDTH_BUCKET <functions-arithmetic:WIDTH_BUCKET>`
     - Which equal-width bucket a value is in
     - Arithmetic
