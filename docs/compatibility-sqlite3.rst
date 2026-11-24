SQLite3 Functions
=================

.. contents::
   :local:
   :depth: 1

How to write the SQL functions of SQLite 3 in vsql. Every built-in function
is here: the core, date and time, aggregate, window, math and JSON functions,
in the same groups as the SQLite documentation, and each one can be linked to
by its name, such as ``compatibility-sqlite3.html#instr``. Functions that have
no equivalent in vsql are listed too, so you can tell that they haven't been
missed.

Differences from SQLite
-----------------------

Each function shows its SQLite signature, and below it the same statement in
vsql with each argument as a comment where its value goes. An example follows
on the example table, with the SQLite statement and its result in vsql:

.. code-block:: sql

  -- instr(X, Y)
  VALUES POSITION(/*Y*/ IN /*X*/);
  -- SELECT instr('Banana', 'na');
  VALUES POSITION('na' IN 'Banana');
  -- COL1: 3

When an optional argument changes the statement, each form has its own
statement and example. A comment that isn't the name of an argument says what
goes there instead, such as ``/*table*/``. A ``SELECT`` without a ``FROM`` is
written as a ``VALUES``, which is the standard form (vsql also takes the
``SELECT`` as an extension).

There are a few other differences to watch for:

- vsql checks types. A column only holds values of its type, so inserting
  ``'many'`` into an ``INTEGER`` column is an error, and there are no implicit
  conversions between text and numbers: ``'10' + 1`` is 11 in SQLite and an
  error in vsql. Use ``CAST``, such as ``CAST(qty AS VARCHAR(11))`` to join a
  number to a text with ``||``.
- A ``DECIMAL`` (or ``NUMERIC``) is exact in vsql, where SQLite stores it as an
  integer or a floating point number. So ``price`` 4.00 is 4 in SQLite and 4.00
  in vsql.
- Dividing two integers gives an integer in both, so ``10 / 4`` is 2. A
  decimal keeps the decimal places of its operands in vsql, so ``1 / 3.0`` is
  0.3 rather than 0.333333333333333. Write ``1 / 3e0`` for a floating point
  result.
- Errors are errors. Dividing by zero, ``sqrt(-1)`` and
  ``CAST('abc' AS INTEGER)`` are ``NULL``, ``NULL`` and 0 in SQLite, and each
  one fails in vsql (see :doc:`sqlstate`).
- A ``DOUBLE PRECISION`` is shown with up to 12 significant digits and an
  exponent, so ``exp(1)`` is 2.718281828459e0 in vsql and 2.71828182845905 in
  SQLite.
- Booleans are ``TRUE`` and ``FALSE``, where SQLite has 1 and 0.
- ``LIKE`` is case-sensitive in vsql, where SQLite ignores the case of ASCII
  letters. Use ``ILIKE``, or ``UPPER`` on both sides.
- Text is in single quotes (``'Apple'``). Double quotes are always names in
  vsql, where SQLite takes ``"Apple"`` as a text when there's no column of
  that name.
- Names that aren't quoted are upper case in vsql, so the column ``name`` is
  shown as ``NAME``, and a column without a name is ``COL1``, ``COL2``, ...
- Dates and times are ``DATE``, ``TIME`` and ``TIMESTAMP`` values, not text or
  numbers, so a text has to be cast (or written as ``DATE '2024-03-05'``)
  before it can be compared with them.
- ``NULL`` and the empty text are different in both, and ``||`` with a
  ``NULL`` is ``NULL`` in both.

Example Table
-------------

The examples use this table, which is the same in SQLite:

.. code-block:: sql

  CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
  INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);

Core Functions
--------------

abs
^^^

Returns the absolute value of a number.

.. code-block:: sql

  -- abs(X)
  VALUES ABS(/*X*/);
  -- SELECT abs(-2.5);
  VALUES ABS(-2.5);
  -- COL1: 2.5

changes
^^^^^^^

.. code-block:: text

  changes()

Returns the number of rows that the last INSERT, UPDATE or DELETE on the connection changed.

No equivalent.

char
^^^^

Returns the text made of the characters with the given Unicode code points.

.. code-block:: sql

  -- char(X1, X2, ..., XN)
  VALUES CHR(/*X1*/) || CHR(/*X2*/);
  -- SELECT char(72, 105);
  VALUES CHR(72) || CHR(105);
  -- COL1: Hi

coalesce
^^^^^^^^

Returns the first of its arguments that isn't NULL.

.. code-block:: sql

  -- coalesce(X, Y, ...)
  VALUES COALESCE(/*X*/, /*Y*/);
  -- SELECT coalesce(qty, 0) FROM products WHERE sku = 'D4';
  SELECT COALESCE(qty, 0) FROM products WHERE sku = 'D4';
  -- COL1: 0

concat
^^^^^^

Joins its arguments into one text, where a NULL counts as an empty text.

.. code-block:: sql

  -- concat(X, ...)
  VALUES CONCAT(/*X1*/, /*X2*/, ...);
  -- SELECT concat(sku, ':', name) FROM products WHERE sku = 'A1';
  SELECT CONCAT(sku, ':', name) FROM products WHERE sku = 'A1';
  -- COL1: A1:Apple

A number has to be cast to text first, such as ``CAST(qty AS VARCHAR(11))``.

concat_ws
^^^^^^^^^

Joins its arguments into one text with a separator between them, leaving out the ones that are NULL.

.. code-block:: sql

  -- concat_ws(SEP, X, ...)
  VALUES CONCAT_WS(/*SEP*/, /*X1*/, /*X2*/, ...);
  -- SELECT concat_ws('-', 'A1', 'Apple');
  VALUES CONCAT_WS('-', 'A1', 'Apple');
  -- COL1: A1-Apple

format
^^^^^^

Builds a text from a format string and values, in the way of the C printf function.

.. code-block:: sql

  -- format(FORMAT, ...)
  VALUES /*text before*/ || CAST(/*value*/ AS VARCHAR(/*length*/)) || /*text after*/;
  -- SELECT format('%s costs %.2f', 'Cherry', 4);
  VALUES 'Cherry' || ' costs ' || CAST(4.00 AS VARCHAR(12));
  -- COL1: Cherry costs 4.00

Each conversion becomes a ``CAST`` to text. Round the number first (with
``ROUND``) for a number of decimal places, and use ``LPAD`` for a width.

glob
^^^^

Tells whether a text matches a pattern, where ``*`` matches any characters and ``?`` matches one, with the case mattering.

.. code-block:: sql

  -- glob(X, Y)
  VALUES /*Y*/ LIKE /*X with % for * and _ for ?*/;
  -- SELECT glob('Ch*', 'Cherry');
  VALUES 'Cherry' LIKE 'Ch%';
  -- COL1: TRUE

SQLite returns 1 or 0, and vsql ``TRUE`` or ``FALSE``. ``Y GLOB X`` is the
same as ``glob(X, Y)``. A list of characters such as ``[abc]`` needs
``SIMILAR TO`` instead of ``LIKE``.

hex
^^^

.. code-block:: text

  hex(X)

Returns the bytes of a value (a blob, or the UTF-8 of a text or number) as hexadecimal digits.

No equivalent.

if
^^^

Returns the value that goes with the first condition that's true, or the last value when none is.

.. code-block:: sql

  -- if(B1, V1, B2, V2, ..., E)
  VALUES CASE WHEN /*B1*/ THEN /*V1*/ WHEN /*B2*/ THEN /*V2*/ ELSE /*E*/ END;
  -- SELECT if(10 > 20, 'many', 'few');
  VALUES CASE WHEN 10 > 20 THEN 'many' ELSE 'few' END;
  -- COL1: few

``if`` is another name for ``iif``. Without the last value, both return
``NULL`` when no condition is true, the same as a ``CASE`` without ``ELSE``.

ifnull
^^^^^^

Returns its first argument, or the second one when the first is NULL.

.. code-block:: sql

  -- ifnull(X, Y)
  VALUES COALESCE(/*X*/, /*Y*/);
  -- SELECT ifnull(qty, -1) FROM products WHERE sku = 'D4';
  SELECT COALESCE(qty, -1) FROM products WHERE sku = 'D4';
  -- COL1: -1

iif
^^^

Returns the value that goes with the first condition that's true, or the last value when none is.

.. code-block:: sql

  -- iif(B1, V1, B2, V2, ..., E)
  VALUES CASE WHEN /*B1*/ THEN /*V1*/ WHEN /*B2*/ THEN /*V2*/ ELSE /*E*/ END;
  -- SELECT iif(4 < 1, 'cheap', 4 < 3.5, 'fair', 'dear');
  VALUES CASE WHEN 4 < 1 THEN 'cheap' WHEN 4 < 3.5 THEN 'fair' ELSE 'dear' END;
  -- COL1: dear

instr
^^^^^

Returns the position of the first place a text is found in another, or 0 when it isn't there.

.. code-block:: sql

  -- instr(X, Y)
  VALUES POSITION(/*Y*/ IN /*X*/);
  -- SELECT instr('Banana', 'na');
  VALUES POSITION('na' IN 'Banana');
  -- COL1: 3

last_insert_rowid
^^^^^^^^^^^^^^^^^

.. code-block:: text

  last_insert_rowid()

Returns the rowid of the row that the last successful INSERT on the connection added.

No equivalent.

length
^^^^^^

Returns the number of characters in a text (or of bytes in a blob).

.. code-block:: sql

  -- length(X)
  VALUES LENGTH(/*X*/);
  -- SELECT length('Cherry');
  VALUES LENGTH('Cherry');
  -- COL1: 6

SQLite counts the characters of a number as text, such as 3 for
``length(1.5)``. In vsql cast it to text first.

like
^^^^

Tells whether a text matches a pattern, where ``%`` matches any characters and ``_`` matches one, without the case of ASCII letters mattering.

.. code-block:: sql

  -- like(X, Y)
  VALUES UPPER(/*Y*/) LIKE UPPER(/*X*/);
  -- SELECT like('%AN%', name) FROM products WHERE sku = 'B2';
  SELECT UPPER(name) LIKE UPPER('%AN%') FROM products WHERE sku = 'B2';
  -- COL1: TRUE

  -- like(X, Y, Z)
  VALUES /*Y*/ LIKE /*X*/ ESCAPE /*Z*/;
  -- SELECT like('10!%', '10%', '!');
  VALUES '10%' LIKE '10!%' ESCAPE '!';
  -- COL1: TRUE

``Y LIKE X`` is the same as ``like(X, Y)``. ``LIKE`` in vsql is
case-sensitive, so both sides are upper-cased when the case mustn't matter
(``ILIKE`` does the same). SQLite returns 1 or 0, and vsql ``TRUE`` or
``FALSE``.

likelihood
^^^^^^^^^^

Returns its first argument unchanged, and tells the query planner how likely it is to be true.

.. code-block:: sql

  -- likelihood(X, Y)
  SELECT /*columns*/ FROM /*table*/ WHERE /*X*/;
  -- SELECT name FROM products WHERE likelihood(price > 3.5, 0.25);
  SELECT name FROM products WHERE price > 3.5;
  -- NAME: Cherry

vsql has no hints for the planner, so the condition is used on its own.

likely
^^^^^^

Returns its argument unchanged, and tells the query planner that it's almost always true.

.. code-block:: sql

  -- likely(X)
  SELECT /*columns*/ FROM /*table*/ WHERE /*X*/;
  -- SELECT name FROM products WHERE likely(qty > 20);
  SELECT name FROM products WHERE qty > 20;
  -- NAME: Banana

load_extension
^^^^^^^^^^^^^^

.. code-block:: text

  load_extension(X, [Y])

Loads an extension from a shared library file into the connection.

No equivalent.

lower
^^^^^

Returns a text in lower case.

.. code-block:: sql

  -- lower(X)
  VALUES LOWER(/*X*/);
  -- SELECT lower('Apple');
  VALUES LOWER('Apple');
  -- COL1: apple

SQLite only changes the ASCII letters, and vsql changes every letter, so
``LOWER('É')`` is ``'é'``.

ltrim
^^^^^

Removes spaces, or any of the given characters, from the start of a text.

.. code-block:: sql

  -- ltrim(X)
  VALUES LTRIM(/*X*/);
  -- SELECT ltrim('  Apple');
  VALUES LTRIM('  Apple');
  -- COL1: Apple

  -- ltrim(X, Y)
  VALUES LTRIM(/*X*/, /*Y*/);
  -- SELECT ltrim('xxAxx', 'x');
  VALUES LTRIM('xxAxx', 'x');
  -- COL1: Axx

max
^^^

With several arguments, returns the largest of them, and with one, the largest value of a column.

.. code-block:: sql

  -- max(X, Y, ...)
  VALUES GREATEST(/*X*/, /*Y*/);
  -- SELECT max(3, 7, 5);
  VALUES GREATEST(3, 7, 5);
  -- COL1: 7

  -- max(X)
  SELECT MAX(/*X*/) FROM /*table*/;
  -- SELECT max(price) FROM products;
  SELECT MAX(price) FROM products;
  -- COL1: 4.00

SQLite stores 4.00 in a ``DECIMAL`` column as the integer 4, and vsql keeps it
as 4.00. Both return ``NULL`` when an argument of the scalar form is
``NULL``.

min
^^^

With several arguments, returns the smallest of them, and with one, the smallest value of a column.

.. code-block:: sql

  -- min(X, Y, ...)
  VALUES LEAST(/*X*/, /*Y*/);
  -- SELECT min(3, 7, 5);
  VALUES LEAST(3, 7, 5);
  -- COL1: 3

  -- min(X)
  SELECT MIN(/*X*/) FROM /*table*/;
  -- SELECT min(qty) FROM products;
  SELECT MIN(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 5

nullif
^^^^^^

Returns NULL when its two arguments are equal, otherwise the first one.

.. code-block:: sql

  -- nullif(X, Y)
  VALUES NULLIF(/*X*/, /*Y*/);
  -- SELECT nullif(qty, 10) FROM products WHERE sku = 'A1';
  SELECT NULLIF(qty, 10) FROM products WHERE sku = 'A1';
  -- COL1: NULL

octet_length
^^^^^^^^^^^^

Returns the number of bytes in the UTF-8 form of a text.

.. code-block:: sql

  -- octet_length(X)
  VALUES OCTET_LENGTH(/*X*/);
  -- SELECT octet_length('café');
  VALUES OCTET_LENGTH('café');
  -- COL1: 5

printf
^^^^^^

Builds a text from a format string and values, the same as format.

.. code-block:: sql

  -- printf(FORMAT, ...)
  VALUES /*text before*/ || CAST(/*value*/ AS VARCHAR(/*length*/)) || /*text after*/;
  -- SELECT printf('%d left', 10);
  VALUES CAST(10 AS VARCHAR(11)) || ' left';
  -- COL1: 10 left

See `format`_.

quote
^^^^^

Returns a value written as an SQL literal, such as a text in single quotes.

.. code-block:: sql

  -- quote(X)
  VALUES '''' || REPLACE(/*X*/, '''', '''''') || '''';
  -- SELECT quote('It''s');
  VALUES '''' || REPLACE('It''s', '''', '''''') || '''';
  -- COL1: 'It''s'

This is for a text. A number cast to text is already a literal, and a
``NULL`` needs a ``CASE`` to become ``'NULL'``.

random
^^^^^^

Returns a random integer.

.. code-block:: sql

  -- random()
  VALUES RANDOM();
  -- SELECT abs(random() % 6) + 1 BETWEEN 1 AND 6;
  VALUES FLOOR(RANDOM() * 6) + 1 BETWEEN 1 AND 6;
  -- COL1: TRUE

SQLite's ``random()`` is any 64-bit integer, and vsql's ``RANDOM()`` is a
``DOUBLE PRECISION`` that's at least 0 and less than 1, so multiply it to get
a range.

randomblob
^^^^^^^^^^

Returns a blob of N random bytes.

.. code-block:: sql

  -- randomblob(N)
  VALUES RANDOM_BINARY(/*N*/);
  -- SELECT length(randomblob(16));
  VALUES OCTET_LENGTH(RANDOM_BINARY(16));
  -- COL1: 16

SQLite's ``randomblob`` gives 1 byte when N is less than 1, and vsql's
``RANDOM_BINARY`` gives no bytes for 0 and an error for a negative N.

replace
^^^^^^^

Replaces every place a text is found in another text with a third text.

.. code-block:: sql

  -- replace(X, Y, Z)
  VALUES REPLACE(/*X*/, /*Y*/, /*Z*/);
  -- SELECT replace('Banana', 'an', 'AN');
  VALUES REPLACE('Banana', 'an', 'AN');
  -- COL1: BANANa

round
^^^^^

Rounds a number to a number of decimal places (0 when it's left out), with halves going away from zero.

.. code-block:: sql

  -- round(X)
  VALUES ROUND(/*X*/);
  -- SELECT round(2.5);
  VALUES ROUND(2.5);
  -- COL1: 3

  -- round(X, Y)
  VALUES ROUND(/*X*/, /*Y*/);
  -- SELECT round(price * 1.1, 2) FROM products WHERE sku = 'A1';
  SELECT ROUND(price * 1.1, 2) FROM products WHERE sku = 'A1';
  -- COL1: 1.65

SQLite always returns a floating point number, such as 3.0. vsql keeps the
type of ``X``, so the result of a ``DECIMAL`` is exact.

rtrim
^^^^^

Removes spaces, or any of the given characters, from the end of a text.

.. code-block:: sql

  -- rtrim(X)
  VALUES RTRIM(/*X*/);
  -- SELECT rtrim('Apple  ') || '|';
  VALUES RTRIM('Apple  ') || '|';
  -- COL1: Apple|

  -- rtrim(X, Y)
  VALUES RTRIM(/*X*/, /*Y*/);
  -- SELECT rtrim('xxAxx', 'x');
  VALUES RTRIM('xxAxx', 'x');
  -- COL1: xxA

sign
^^^^

Returns -1, 0 or 1 for a negative number, zero or a positive number.

.. code-block:: sql

  -- sign(X)
  VALUES SIGN(/*X*/);
  -- SELECT sign(-7.5);
  VALUES SIGN(-7.5);
  -- COL1: -1

SQLite returns ``NULL`` for a text that isn't a number, where vsql won't
accept a text at all.

soundex
^^^^^^^

.. code-block:: text

  soundex(X)

Returns the four character Soundex code of a text. Only when SQLite is built with SQLITE_SOUNDEX.

No equivalent.

sqlite_compileoption_get
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  sqlite_compileoption_get(N)

Returns the Nth option that SQLite was compiled with.

No equivalent.

sqlite_compileoption_used
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  sqlite_compileoption_used(X)

Tells whether SQLite was compiled with an option.

No equivalent.

sqlite_offset
^^^^^^^^^^^^^

.. code-block:: text

  sqlite_offset(X)

Returns the byte offset in the database file of the record that a column was read from.

No equivalent.

sqlite_source_id
^^^^^^^^^^^^^^^^

.. code-block:: text

  sqlite_source_id()

Returns the date and check-in hash of the source code of SQLite.

No equivalent.

sqlite_version
^^^^^^^^^^^^^^

.. code-block:: text

  sqlite_version()

Returns the version of the SQLite library.

No equivalent.

substr
^^^^^^

Returns part of a text, from a starting character, for a number of characters (or to the end).

.. code-block:: sql

  -- substr(X, Y, Z)
  VALUES SUBSTRING(/*X*/ FROM /*Y*/ FOR /*Z*/);
  -- SELECT substr('Cherry', 2, 3);
  VALUES SUBSTRING('Cherry' FROM 2 FOR 3);
  -- COL1: her

  -- substr(X, Y)
  VALUES SUBSTRING(/*X*/ FROM /*Y*/);
  -- SELECT substr('Cherry', 3);
  VALUES SUBSTRING('Cherry' FROM 3);
  -- COL1: erry

A negative ``Y`` counts from the end in SQLite, so ``substr('Cherry', -3)``
is ``'rry'``. In vsql that's ``SUBSTRING('Cherry' FROM CHAR_LENGTH('Cherry') -
2)``, since a start before the first character only shortens the result.

substring
^^^^^^^^^

Returns part of a text, the same as substr.

.. code-block:: sql

  -- substring(X, Y, Z)
  VALUES SUBSTRING(/*X*/ FROM /*Y*/ FOR /*Z*/);
  -- SELECT substring('Banana', 3, 2);
  VALUES SUBSTRING('Banana' FROM 3 FOR 2);
  -- COL1: na

  -- substring(X, Y)
  VALUES SUBSTRING(/*X*/ FROM /*Y*/);
  -- SELECT substring('Banana', 3);
  VALUES SUBSTRING('Banana' FROM 3);
  -- COL1: nana

See `substr`_.

total_changes
^^^^^^^^^^^^^

.. code-block:: text

  total_changes()

Returns the number of rows that every INSERT, UPDATE and DELETE has changed since the connection was opened.

No equivalent.

trim
^^^^

Removes spaces, or any of the given characters, from both ends of a text.

.. code-block:: sql

  -- trim(X)
  VALUES TRIM(/*X*/);
  -- SELECT '|' || trim('  Apple  ') || '|';
  VALUES '|' || TRIM('  Apple  ') || '|';
  -- COL1: |Apple|

  -- trim(X, Y)
  VALUES BTRIM(/*X*/, /*Y*/);
  -- SELECT trim('xxAxx', 'x');
  VALUES BTRIM('xxAxx', 'x');
  -- COL1: A

typeof
^^^^^^

.. code-block:: text

  typeof(X)

Returns the storage class of a value: null, integer, real, text or blob.

No equivalent.

unhex
^^^^^

.. code-block:: text

  unhex(X, [Y])

Returns the blob of the bytes that a text of hexadecimal digits stands for.

No equivalent.

unicode
^^^^^^^

Returns the Unicode code point of the first character of a text.

.. code-block:: sql

  -- unicode(X)
  VALUES UNICODE(/*X*/);
  -- SELECT unicode('A');
  VALUES UNICODE('A');
  -- COL1: 65

unistr
^^^^^^

Returns a text with its ``\uXXXX`` and ``\UXXXXXXXX`` escapes replaced by the characters they stand for.

.. code-block:: sql

  -- unistr(X)
  VALUES /*text before*/ || CHR(/*code point*/) || /*text after*/;
  -- SELECT unistr('caf\u00e9');
  VALUES 'caf' || CHR(233);
  -- COL1: café

For a literal, vsql also has Unicode strings: ``U&'caf\00e9'`` (and
``\+XXXXXX`` for six digits).

unistr_quote
^^^^^^^^^^^^

.. code-block:: text

  unistr_quote(X)

Returns a value written as an SQL literal, with the control characters as unistr() escapes.

No equivalent.

unlikely
^^^^^^^^

Returns its argument unchanged, and tells the query planner that it's almost always false.

.. code-block:: sql

  -- unlikely(X)
  SELECT /*columns*/ FROM /*table*/ WHERE /*X*/;
  -- SELECT name FROM products WHERE unlikely(qty IS NULL);
  SELECT name FROM products WHERE qty IS NULL;
  -- NAME: Date

upper
^^^^^

Returns a text in upper case.

.. code-block:: sql

  -- upper(X)
  VALUES UPPER(/*X*/);
  -- SELECT upper('Apple');
  VALUES UPPER('Apple');
  -- COL1: APPLE

SQLite only changes the ASCII letters, and vsql changes every letter, so
``UPPER('é')`` is ``'É'``.

zeroblob
^^^^^^^^

.. code-block:: text

  zeroblob(N)

Returns a blob of N zero bytes.

No equivalent.

Date and Time Functions
-----------------------

A time value in SQLite is a text, a Julian day number or a Unix time, and the
functions take modifiers such as ``'+1 day'`` or ``'start of month'``. vsql
has ``DATE``, ``TIME`` and ``TIMESTAMP`` types instead (see
:doc:`dates-times`), but no date arithmetic, so most modifiers have no
equivalent. The parts of a value come from ``EXTRACT``, and ``MAKE_DATE``,
``MAKE_TIME`` and ``MAKE_TIMESTAMP`` build a value from its parts (see
:doc:`functions-date-and-time`).

date
^^^^

Returns the date of a time value as YYYY-MM-DD.

.. code-block:: sql

  -- date(time-value)
  VALUES CAST(/*time-value*/ AS DATE);
  -- SELECT date('2024-03-05 14:30:15');
  VALUES CAST(TIMESTAMP '2024-03-05 14:30:15' AS DATE);
  -- COL1: 2024-03-05

  -- date('now')
  VALUES CURRENT_DATE;
  -- SELECT date('now') > '2020-01-01';
  VALUES CURRENT_DATE > DATE '2020-01-01';
  -- COL1: TRUE

  -- date(time-value, 'start of month')
  VALUES CAST(DATE_TRUNC('month', /*time-value*/) AS DATE);
  -- SELECT date('2024-03-05 14:30:15', 'start of month');
  VALUES CAST(DATE_TRUNC('month', TIMESTAMP '2024-03-05 14:30:15') AS DATE);
  -- COL1: 2024-03-01

A text has to be a timestamp literal (or cast to ``TIMESTAMP``) first, since
only ``'2024-03-05'`` itself can be cast to a ``DATE``. ``'now'`` is in UTC
in SQLite, and ``CURRENT_DATE`` is in the time zone of the session. ``'start of year'`` is
``DATE_TRUNC('year', ...)``, and ``'start of day'`` (of a ``datetime``) is
``DATE_TRUNC('day', ...)``.

datetime
^^^^^^^^

Returns the date and time of a time value as YYYY-MM-DD HH:MM:SS.

.. code-block:: sql

  -- datetime(time-value)
  VALUES CAST(/*time-value*/ AS TIMESTAMP(0));
  -- SELECT datetime('2024-03-05 14:30:15.250');
  VALUES CAST(TIMESTAMP '2024-03-05 14:30:15.25' AS TIMESTAMP(0));
  -- COL1: 2024-03-05T14:30:15

  -- datetime('now')
  VALUES LOCALTIMESTAMP(0);
  -- SELECT datetime('now') > '2020-01-01 00:00:00';
  VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

vsql shows a ``TIMESTAMP`` with a ``T`` between the date and the time.

julianday
^^^^^^^^^

Returns the Julian day number of a time value, a number of days with a fraction.

.. code-block:: sql

  -- julianday(time-value)
  VALUES EXTRACT(EPOCH FROM /*time-value*/) / 86400.00000000 + 2440587.5;
  -- SELECT julianday('2024-03-05 14:30:15');
  VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 14:30:15') / 86400.00000000 + 2440587.5;
  -- COL1: 2460375.1043402777777777

The Julian day is the seconds since 1970 divided into days, plus the Julian day
of 1970-01-01 (2440587.5). The decimal places of ``86400.00000000`` set the
places of the result, which is cut rather than rounded, so SQLite has
2460375.10434028. Dividing by ``86400e0`` gives a ``DOUBLE PRECISION``
instead, which is shown with only 12 significant digits.

``EXTRACT(JULIAN FROM ...)`` (as in PostgreSQL) is a Julian day that starts at
local midnight, rather than at noon UTC, so it's 0.5 more than ``julianday``
for a value without a time zone:

.. code-block:: sql

  VALUES EXTRACT(JULIAN FROM TIMESTAMP '2024-03-05 14:30:15') - 0.5;
  -- COL1: 2460375.104340277777

strftime
^^^^^^^^

Returns parts of a time value written by a format, such as %Y for the year.

.. code-block:: sql

  -- strftime('%Y', time-value)
  VALUES EXTRACT(YEAR FROM /*time-value*/);
  -- SELECT strftime('%Y', '2024-03-05');
  VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
  -- COL1: 2024

  -- strftime('%j', time-value)
  VALUES EXTRACT(DOY FROM /*time-value*/);
  -- SELECT strftime('%j', '2024-03-05');
  VALUES EXTRACT(DOY FROM DATE '2024-03-05');
  -- COL1: 65

  -- strftime('%w', time-value)
  VALUES EXTRACT(DOW FROM /*time-value*/);
  -- SELECT strftime('%w', '2024-03-05');
  VALUES EXTRACT(DOW FROM DATE '2024-03-05');
  -- COL1: 2

  -- strftime('%H:%M', time-value)
  VALUES SUBSTRING(CAST(/*time-value*/ AS VARCHAR(15)) FROM 7 FOR 5);
  -- SELECT strftime('%H:%M', '14:30:15');
  VALUES SUBSTRING(CAST(TIME '14:30:15' AS VARCHAR(15)) FROM 7 FOR 5);
  -- COL1: 14:30

``EXTRACT`` returns an ``INTEGER``, where SQLite returns a text padded with
zeros (``'065'``). ``%m``, ``%d``, ``%H``, ``%M`` and ``%S`` are ``MONTH``,
``DAY``, ``HOUR``, ``MINUTE`` and ``SECOND``, ``%u`` is ``ISODOW``, ``%V`` is
``WEEK``, ``%G`` is ``ISOYEAR`` and ``%s`` is ``EPOCH`` (see `unixepoch`_).
For a padded text, cut it out of the value cast to text: a ``DATE`` cast to
text is ``DATE '2024-03-05'`` and a ``TIME`` is ``TIME '14:30:15'``, which is
where the positions come from, so ``%m`` is ``FROM 12 FOR 2`` and ``%d`` is
``FROM 15 FOR 2``. Cast a ``TIMESTAMP`` to ``DATE`` or ``TIME`` first.

time
^^^^

Returns the time of a time value as HH:MM:SS.

.. code-block:: sql

  -- time(time-value)
  VALUES CAST(/*time-value*/ AS TIME);
  -- SELECT time('2024-03-05 14:30:15');
  VALUES CAST(TIMESTAMP '2024-03-05 14:30:15' AS TIME);
  -- COL1: 14:30:15

  -- time('now')
  VALUES LOCALTIME;
  -- SELECT time('now') >= '00:00:00';
  VALUES LOCALTIME >= TIME '00:00:00';
  -- COL1: TRUE

``'now'`` is in UTC in SQLite, and ``LOCALTIME`` is in the time zone of the
session.

timediff
^^^^^^^^

.. code-block:: text

  timediff(time-value, time-value)

Returns the years, months, days, hours, minutes and seconds between two time values.

No equivalent.

unixepoch
^^^^^^^^^

Returns the number of seconds between 1970-01-01 00:00:00 UTC and a time value.

.. code-block:: sql

  -- unixepoch(time-value)
  VALUES EXTRACT(EPOCH FROM /*time-value*/);
  -- SELECT unixepoch('2024-03-05 14:30:15');
  VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 14:30:15');
  -- COL1: 1709649015

A ``TIMESTAMP`` without a time zone is taken to be in UTC, the same as in
SQLite. vsql keeps the fraction of a second of a ``TIMESTAMP(p)``, where SQLite
drops it unless the ``'subsec'`` modifier is given.

Aggregate Functions
-------------------

``max`` and ``min`` have both a scalar and an aggregate form, and are under
`Core Functions`_.

avg
^^^

Returns the average of the values of a column that aren't NULL.

.. code-block:: sql

  -- avg(X)
  SELECT AVG(CAST(/*X*/ AS DOUBLE PRECISION)) FROM /*table*/;
  -- SELECT avg(price) FROM products;
  SELECT AVG(CAST(price AS DOUBLE PRECISION)) FROM products;
  -- COL1: 2.1875e0

SQLite always returns a floating point number. vsql keeps the type of the
column, so ``AVG(price)`` is 2.18, rounded down to the 2 decimal places of
``price``.

count
^^^^^

Counts the rows, or the values of a column that aren't NULL.

.. code-block:: sql

  -- count(X)
  SELECT COUNT(/*X*/) FROM /*table*/;
  -- SELECT count(qty) FROM products;
  SELECT COUNT(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 3

  -- count(*)
  SELECT COUNT(*) FROM /*table*/;
  -- SELECT count(*) FROM products;
  SELECT COUNT(*) FROM products;
  -- COL1: 4

group_concat
^^^^^^^^^^^^

Joins the values of a column that aren't NULL into one text, with a comma (or another separator) between them.

.. code-block:: sql

  -- group_concat(X ORDER BY Z)
  SELECT LISTAGG(/*X*/, ',') WITHIN GROUP (ORDER BY /*Z*/) FROM /*table*/;
  -- SELECT group_concat(name ORDER BY name) FROM products;
  SELECT LISTAGG(name, ',') WITHIN GROUP (ORDER BY name) FROM products;
  -- COL1: Apple,Banana,Cherry,Date

  -- group_concat(X, Y ORDER BY Z)
  SELECT LISTAGG(/*X*/, /*Y*/) WITHIN GROUP (ORDER BY /*Z*/) FROM /*table*/;
  -- SELECT group_concat(sku, '; ' ORDER BY price DESC) FROM products;
  SELECT LISTAGG(sku, '; ') WITHIN GROUP (ORDER BY price DESC) FROM products;
  -- COL1: C3; D4; A1; B2

The separator has to be a literal. ``LISTAGG`` needs a ``WITHIN GROUP``,
where SQLite's order is arbitrary without the ``ORDER BY``.

median
^^^^^^

Returns the middle value of a column, or the average of the two in the middle. Only when SQLite is built with SQLITE_ENABLE_PERCENTILE.

.. code-block:: sql

  -- median(X)
  SELECT MEDIAN(/*X*/) FROM /*table*/;
  -- SELECT median(price) FROM products;
  SELECT MEDIAN(price) FROM products;
  -- COL1: 2.25e0

``MEDIAN`` is a vsql extension. The standard equivalent is
``PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(X AS DOUBLE PRECISION))``:
vsql's ``PERCENTILE_CONT`` returns a value between two values with the type of
the sort key, so without the cast the result would be cut to the 2 decimal
places of ``price``.

percentile
^^^^^^^^^^

Returns the value of a column at a percentage (0 to 100) of the way through its sorted values, between two values when it falls between them. Only when SQLite is built with SQLITE_ENABLE_PERCENTILE.

.. code-block:: sql

  -- percentile(Y, P)
  SELECT PERCENTILE_CONT(/*P*/ / 100e0) WITHIN GROUP (ORDER BY CAST(/*Y*/ AS DOUBLE PRECISION)) FROM /*table*/;
  -- SELECT percentile(price, 25) FROM products;
  SELECT PERCENTILE_CONT(25 / 100e0) WITHIN GROUP (ORDER BY CAST(price AS DOUBLE PRECISION)) FROM products;
  -- COL1: 1.1875e0

Divide by ``100e0``, not ``100.0``: ``25 / 100.0`` is 0.2 in vsql, since a
decimal keeps the decimal places of its operands. See `median`_ for the
cast.

percentile_cont
^^^^^^^^^^^^^^^

Returns the value of a column at a fraction (0 to 1) of the way through its sorted values, between two values when it falls between them. Only when SQLite is built with SQLITE_ENABLE_PERCENTILE.

.. code-block:: sql

  -- percentile_cont(Y, P)
  SELECT PERCENTILE_CONT(/*P*/) WITHIN GROUP (ORDER BY CAST(/*Y*/ AS DOUBLE PRECISION)) FROM /*table*/;
  -- SELECT percentile_cont(price, 0.75) FROM products;
  SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CAST(price AS DOUBLE PRECISION)) FROM products;
  -- COL1: 3.25e0

percentile_disc
^^^^^^^^^^^^^^^

Returns the first value of a column that's at least a fraction (0 to 1) of the way through its sorted values. Only when SQLite is built with SQLITE_ENABLE_PERCENTILE.

.. code-block:: sql

  -- percentile_disc(Y, P)
  SELECT PERCENTILE_DISC(/*P*/) WITHIN GROUP (ORDER BY /*Y*/) FROM /*table*/;
  -- SELECT percentile_disc(price, 0.5) FROM products;
  SELECT PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 1.5e0

string_agg
^^^^^^^^^^

Joins the values of a column that aren't NULL into one text, with a separator between them.

.. code-block:: sql

  -- string_agg(X, Y ORDER BY Z)
  SELECT LISTAGG(/*X*/, /*Y*/) WITHIN GROUP (ORDER BY /*Z*/) FROM /*table*/;
  -- SELECT string_agg(name, ' / ' ORDER BY qty) FROM products;
  SELECT LISTAGG(name, ' / ') WITHIN GROUP (ORDER BY qty) FROM products;
  -- COL1: Date / Cherry / Apple / Banana

See `group_concat`_.

sum
^^^

Adds up the values of a column that aren't NULL, or returns NULL when there are none.

.. code-block:: sql

  -- sum(X)
  SELECT SUM(/*X*/) FROM /*table*/;
  -- SELECT sum(qty) FROM products;
  SELECT SUM(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 55

total
^^^^^

Adds up the values of a column that aren't NULL as a floating point number, and returns 0.0 when there are none.

.. code-block:: sql

  -- total(X)
  SELECT COALESCE(SUM(CAST(/*X*/ AS DOUBLE PRECISION)), 0e0) FROM /*table*/;
  -- SELECT total(qty) FROM products WHERE qty > 100;
  SELECT COALESCE(SUM(CAST(qty AS DOUBLE PRECISION)), 0e0) FROM products WHERE qty > 100;
  -- COL1: 0e0

Window Functions
----------------

vsql doesn't have window functions (``OVER``) yet. Most of them can be
written as a subquery that looks at the other rows, which is shown here with
``OVER (ORDER BY price)``. ``/*key*/`` is what the window is ordered by. A
``PARTITION BY`` becomes one more condition in the ``WHERE`` of the
subquery, such as ``t2.category = t.category``.

cume_dist
^^^^^^^^^

Returns the fraction of the rows that come before the current row or are tied with it.

.. code-block:: sql

  -- cume_dist() OVER (ORDER BY key)
  SELECT (SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*key*/ <= t./*key*/) / CAST((SELECT COUNT(*) FROM /*table*/) AS DOUBLE PRECISION) FROM /*table*/ AS t;
  -- SELECT name, cume_dist() OVER (ORDER BY price) AS cd FROM products ORDER BY price;
  SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price <= p.price)
    / CAST((SELECT COUNT(*) FROM products) AS DOUBLE PRECISION) AS cd
  FROM products AS p ORDER BY price;
  -- NAME: Banana CD: 0.25e0
  -- NAME: Apple CD: 0.5e0
  -- NAME: Date CD: 0.75e0
  -- NAME: Cherry CD: 1e0

dense_rank
^^^^^^^^^^

Returns the rank of the current row, where tied rows have the same rank and no ranks are skipped after them.

.. code-block:: sql

  -- dense_rank() OVER (ORDER BY key)
  SELECT (SELECT COUNT(DISTINCT t2./*key*/) FROM /*table*/ AS t2 WHERE t2./*key*/ <= t./*key*/) FROM /*table*/ AS t;
  -- SELECT name, dense_rank() OVER (ORDER BY price) AS r FROM products ORDER BY price;
  SELECT name, (SELECT COUNT(DISTINCT p2.price) FROM products AS p2 WHERE p2.price <= p.price) AS r
  FROM products AS p ORDER BY price;
  -- NAME: Banana R: 1
  -- NAME: Apple R: 2
  -- NAME: Date R: 3
  -- NAME: Cherry R: 4

A ``NULL`` key is never ``<=`` another one, so its rank is 0 here, where
SQLite sorts ``NULL`` first and gives it rank 1.

first_value
^^^^^^^^^^^

Returns an expression for the first row of the window frame.

.. code-block:: sql

  -- first_value(expr) OVER (ORDER BY key)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 ORDER BY t2./*key*/ FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, first_value(name) OVER (ORDER BY price) AS f FROM products ORDER BY price;
  SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS f
  FROM products AS p ORDER BY price;
  -- NAME: Banana F: Banana
  -- NAME: Apple F: Banana
  -- NAME: Date F: Banana
  -- NAME: Cherry F: Banana

lag
^^^

Returns an expression for the row a number of rows (1 by default) before the current row, or a default (NULL by default) when there's no such row.

.. code-block:: sql

  -- lag(expr) OVER (ORDER BY key)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 WHERE t2./*key*/ < t./*key*/ ORDER BY t2./*key*/ DESC FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, lag(name) OVER (ORDER BY price) AS prev FROM products ORDER BY price;
  SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price < p.price
    ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS prev
  FROM products AS p ORDER BY price;
  -- NAME: Banana PREV: NULL
  -- NAME: Apple PREV: Banana
  -- NAME: Date PREV: Apple
  -- NAME: Cherry PREV: Date

For ``lag(expr, offset, default)``, add ``OFFSET offset - 1 ROWS`` before the
``FETCH`` and put the subquery in a ``COALESCE`` with the default. The key
must be unique, or the rows tied with the current row are skipped.

last_value
^^^^^^^^^^

Returns an expression for the last row of the window frame.

.. code-block:: sql

  -- last_value(expr) OVER (ORDER BY key ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 ORDER BY t2./*key*/ DESC FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, last_value(name) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS l FROM products ORDER BY price;
  SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS l
  FROM products AS p ORDER BY price;
  -- NAME: Banana L: Cherry
  -- NAME: Apple L: Cherry
  -- NAME: Date L: Cherry
  -- NAME: Cherry L: Cherry

With only ``ORDER BY``, the frame ends at the current row, so
``last_value`` is the expression of the current row itself (or of the last
row tied with it).

lead
^^^^

Returns an expression for the row a number of rows (1 by default) after the current row, or a default (NULL by default) when there's no such row.

.. code-block:: sql

  -- lead(expr) OVER (ORDER BY key)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 WHERE t2./*key*/ > t./*key*/ ORDER BY t2./*key*/ FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, lead(name) OVER (ORDER BY price) AS next FROM products ORDER BY price;
  SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price > p.price
    ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS next
  FROM products AS p ORDER BY price;
  -- NAME: Banana NEXT: Apple
  -- NAME: Apple NEXT: Date
  -- NAME: Date NEXT: Cherry
  -- NAME: Cherry NEXT: NULL

See `lag`_ for the offset and the default.

nth_value
^^^^^^^^^

Returns an expression for the Nth row of the window frame, or NULL when the frame has fewer rows.

.. code-block:: sql

  -- nth_value(expr, N) OVER (ORDER BY key ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 ORDER BY t2./*key*/ OFFSET /*N*/ - 1 ROWS FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, nth_value(name, 2) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS n FROM products ORDER BY price;
  SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price OFFSET 1 ROW FETCH FIRST 1 ROW ONLY) AS n
  FROM products AS p ORDER BY price;
  -- NAME: Banana N: Apple
  -- NAME: Apple N: Apple
  -- NAME: Date N: Apple
  -- NAME: Cherry N: Apple

With only ``ORDER BY``, the frame ends at the current row, so SQLite
returns ``NULL`` until the frame has N rows.

ntile
^^^^^

Splits the rows into N groups of nearly the same size, and returns the number of the group of the current row.

.. code-block:: sql

  -- ntile(N) OVER (ORDER BY key)
  SELECT ((SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*key*/ < t./*key*/) * /*N*/ / (SELECT COUNT(*) FROM /*table*/)) + 1 FROM /*table*/ AS t;
  -- SELECT name, ntile(2) OVER (ORDER BY price) AS g FROM products ORDER BY price;
  SELECT name, ((SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) * 2
    / (SELECT COUNT(*) FROM products)) + 1 AS g
  FROM products AS p ORDER BY price;
  -- NAME: Banana G: 1
  -- NAME: Apple G: 1
  -- NAME: Date G: 2
  -- NAME: Cherry G: 2

When the rows can't be split evenly, SQLite makes the first groups the
larger ones, and this can put a larger group after a smaller one (10 rows in
4 groups are 3, 2, 3 and 2 rows, rather than 3, 3, 2 and 2). The key must be
unique.

percent_rank
^^^^^^^^^^^^

Returns the rank of the current row as a fraction from 0 to 1, which is (rank - 1) / (rows - 1).

.. code-block:: sql

  -- percent_rank() OVER (ORDER BY key)
  SELECT (SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*key*/ < t./*key*/) / CAST((SELECT COUNT(*) FROM /*table*/) - 1 AS DOUBLE PRECISION) FROM /*table*/ AS t;
  -- SELECT name, percent_rank() OVER (ORDER BY price) AS pr FROM products ORDER BY price;
  SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price)
    / CAST((SELECT COUNT(*) FROM products) - 1 AS DOUBLE PRECISION) AS pr
  FROM products AS p ORDER BY price;
  -- NAME: Banana PR: 0e0
  -- NAME: Apple PR: 0.333333333333e0
  -- NAME: Date PR: 0.666666666667e0
  -- NAME: Cherry PR: 1e0

rank
^^^^

Returns the rank of the current row, where tied rows have the same rank and the ranks after them are skipped.

.. code-block:: sql

  -- rank() OVER (ORDER BY key)
  SELECT 1 + (SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*key*/ < t./*key*/) FROM /*table*/ AS t;
  -- SELECT name, rank() OVER (ORDER BY price DESC) AS r FROM products ORDER BY price DESC;
  SELECT name, 1 + (SELECT COUNT(*) FROM products AS p2 WHERE p2.price > p.price) AS r
  FROM products AS p ORDER BY price DESC;
  -- NAME: Cherry R: 1
  -- NAME: Date R: 2
  -- NAME: Apple R: 3
  -- NAME: Banana R: 4

For ``ORDER BY key DESC``, count the rows where ``t2.key > t.key``. vsql's
``RANK(x) WITHIN GROUP (ORDER BY key)`` gives the rank that a value would
have.

row_number
^^^^^^^^^^

Returns the number of the current row, counting from 1.

.. code-block:: sql

  -- row_number() OVER (ORDER BY key)
  SELECT (SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*key*/ <= t./*key*/) FROM /*table*/ AS t;
  -- SELECT name, row_number() OVER (ORDER BY price) AS rn FROM products ORDER BY price;
  SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price <= p.price) AS rn
  FROM products AS p ORDER BY price;
  -- NAME: Banana RN: 1
  -- NAME: Apple RN: 2
  -- NAME: Date RN: 3
  -- NAME: Cherry RN: 4

The key must be unique, or tied rows have the same number.

Math Functions
--------------

acos
^^^^

Returns the arccosine of a number, in radians.

.. code-block:: sql

  -- acos(X)
  VALUES ACOS(/*X*/);
  -- SELECT acos(0.5);
  VALUES ACOS(0.5);
  -- COL1: 1.047197551197e0

acosh
^^^^^

Returns the inverse hyperbolic cosine of a number.

.. code-block:: sql

  -- acosh(X)
  VALUES LN(/*X*/ + SQRT(/*X*/ * /*X*/ - 1));
  -- SELECT acosh(2);
  VALUES LN(2e0 + SQRT(2e0 * 2e0 - 1));
  -- COL1: 1.316957896925e0

asin
^^^^

Returns the arcsine of a number, in radians.

.. code-block:: sql

  -- asin(X)
  VALUES ASIN(/*X*/);
  -- SELECT asin(0.5);
  VALUES ASIN(0.5);
  -- COL1: 0.523598775598e0

asinh
^^^^^

Returns the inverse hyperbolic sine of a number.

.. code-block:: sql

  -- asinh(X)
  VALUES LN(/*X*/ + SQRT(/*X*/ * /*X*/ + 1));
  -- SELECT asinh(1);
  VALUES LN(1e0 + SQRT(1e0 * 1e0 + 1));
  -- COL1: 0.88137358702e0

atan
^^^^

Returns the arctangent of a number, in radians.

.. code-block:: sql

  -- atan(X)
  VALUES ATAN(/*X*/);
  -- SELECT atan(1);
  VALUES ATAN(1);
  -- COL1: 0.785398163397e0

atan2
^^^^^

Returns the angle, in radians, of the point (X, Y) from the X axis.

.. code-block:: sql

  -- atan2(Y, X)
  VALUES ATAN2(/*Y*/, /*X*/);
  -- SELECT atan2(1, 2);
  VALUES ATAN2(1, 2);
  -- COL1: 0.463647609001e0

atanh
^^^^^

Returns the inverse hyperbolic tangent of a number.

.. code-block:: sql

  -- atanh(X)
  VALUES 0.5e0 * LN((1 + /*X*/) / (1 - /*X*/));
  -- SELECT atanh(0.5);
  VALUES 0.5e0 * LN((1 + 0.5e0) / (1 - 0.5e0));
  -- COL1: 0.549306144334e0

ceil
^^^^

Rounds a number up to the next integer.

.. code-block:: sql

  -- ceil(X)
  VALUES CEIL(/*X*/);
  -- SELECT ceil(1.2);
  VALUES CEIL(1.2);
  -- COL1: 2

SQLite returns a floating point number for a floating point ``X``, such as
2.0. vsql keeps the type of ``X``.

ceiling
^^^^^^^

Rounds a number up to the next integer, the same as ceil.

.. code-block:: sql

  -- ceiling(X)
  VALUES CEILING(/*X*/);
  -- SELECT ceiling(-1.2);
  VALUES CEILING(-1.2);
  -- COL1: -1

cos
^^^

Returns the cosine of an angle in radians.

.. code-block:: sql

  -- cos(X)
  VALUES COS(/*X*/);
  -- SELECT cos(0);
  VALUES COS(0);
  -- COL1: 1e0

cosh
^^^^

Returns the hyperbolic cosine of a number.

.. code-block:: sql

  -- cosh(X)
  VALUES COSH(/*X*/);
  -- SELECT cosh(1);
  VALUES COSH(1);
  -- COL1: 1.543080634815e0

degrees
^^^^^^^

Converts an angle from radians to degrees.

.. code-block:: sql

  -- degrees(X)
  VALUES DEGREES(/*X*/);
  -- SELECT degrees(pi());
  VALUES DEGREES(PI());
  -- COL1: 180e0

exp
^^^

Returns e raised to a power.

.. code-block:: sql

  -- exp(X)
  VALUES EXP(/*X*/);
  -- SELECT exp(1);
  VALUES EXP(1);
  -- COL1: 2.718281828459e0

floor
^^^^^

Rounds a number down to the next integer.

.. code-block:: sql

  -- floor(X)
  VALUES FLOOR(/*X*/);
  -- SELECT floor(-1.2);
  VALUES FLOOR(-1.2);
  -- COL1: -2

ln
^^^

Returns the natural logarithm of a number.

.. code-block:: sql

  -- ln(X)
  VALUES LN(/*X*/);
  -- SELECT ln(10);
  VALUES LN(10);
  -- COL1: 2.302585092994e0

log
^^^

Returns the logarithm of a number to base 10, or to a given base.

.. code-block:: sql

  -- log(X)
  VALUES LOG10(/*X*/);
  -- SELECT log(1000);
  VALUES LOG10(1000);
  -- COL1: 3e0

  -- log(B, X)
  VALUES LOG(/*B*/, /*X*/);
  -- SELECT log(2, 8);
  VALUES LOG(2, 8);
  -- COL1: 3e0

With one argument, SQLite's ``log`` is to base 10, the same as ``log10``.

log10
^^^^^

Returns the logarithm of a number to base 10.

.. code-block:: sql

  -- log10(X)
  VALUES LOG10(/*X*/);
  -- SELECT log10(0.01);
  VALUES LOG10(0.01);
  -- COL1: -2e0

log2
^^^^

Returns the logarithm of a number to base 2.

.. code-block:: sql

  -- log2(X)
  VALUES LOG(2, /*X*/);
  -- SELECT log2(1024);
  VALUES LOG(2, 1024);
  -- COL1: 10e0

mod
^^^

Returns the remainder of dividing one number by another.

.. code-block:: sql

  -- mod(X, Y)
  VALUES MOD(/*X*/, /*Y*/);
  -- SELECT mod(7.5, 2);
  VALUES MOD(7.5, 2);
  -- COL1: 1.5

The ``%`` operator of SQLite is the same for integers. vsql has no ``%``
operator.

pi
^^^

Returns the number pi.

.. code-block:: sql

  -- pi()
  VALUES PI();
  -- SELECT pi();
  VALUES PI();
  -- COL1: 3.14159265359e0

pow
^^^

Raises a number to a power.

.. code-block:: sql

  -- pow(X, Y)
  VALUES POWER(/*X*/, /*Y*/);
  -- SELECT pow(2, 10);
  VALUES POWER(2, 10);
  -- COL1: 1024e0

power
^^^^^

Raises a number to a power, the same as pow.

.. code-block:: sql

  -- power(X, Y)
  VALUES POWER(/*X*/, /*Y*/);
  -- SELECT power(9, 0.5);
  VALUES POWER(9, 0.5);
  -- COL1: 3e0

radians
^^^^^^^

Converts an angle from degrees to radians.

.. code-block:: sql

  -- radians(X)
  VALUES RADIANS(/*X*/);
  -- SELECT radians(180);
  VALUES RADIANS(180);
  -- COL1: 3.14159265359e0

sin
^^^

Returns the sine of an angle in radians.

.. code-block:: sql

  -- sin(X)
  VALUES SIN(/*X*/);
  -- SELECT sin(pi() / 2);
  VALUES SIN(PI() / 2);
  -- COL1: 1e0

sinh
^^^^

Returns the hyperbolic sine of a number.

.. code-block:: sql

  -- sinh(X)
  VALUES SINH(/*X*/);
  -- SELECT sinh(1);
  VALUES SINH(1);
  -- COL1: 1.175201193644e0

sqrt
^^^^

Returns the square root of a number.

.. code-block:: sql

  -- sqrt(X)
  VALUES SQRT(/*X*/);
  -- SELECT sqrt(2);
  VALUES SQRT(2);
  -- COL1: 1.414213562373e0

A negative number is ``NULL`` in SQLite and a ``2201F`` error in vsql.

tan
^^^

Returns the tangent of an angle in radians.

.. code-block:: sql

  -- tan(X)
  VALUES TAN(/*X*/);
  -- SELECT tan(pi() / 4);
  VALUES TAN(PI() / 4);
  -- COL1: 1e0

tanh
^^^^

Returns the hyperbolic tangent of a number.

.. code-block:: sql

  -- tanh(X)
  VALUES TANH(/*X*/);
  -- SELECT tanh(1);
  VALUES TANH(1);
  -- COL1: 0.761594155956e0

trunc
^^^^^

Removes the fraction of a number, rounding it towards zero.

.. code-block:: sql

  -- trunc(X)
  VALUES TRUNC(/*X*/);
  -- SELECT trunc(-2.7);
  VALUES TRUNC(-2.7);
  -- COL1: -2

JSON Functions
--------------

vsql has no JSON type or functions. JSON is text, so simple JSON can be built
with ``||``, but nothing can read it. Every ``jsonb`` function works on the
binary JSONB form that only SQLite reads, so they have no equivalent.

->
^^^

.. code-block:: text

  json -> path

Returns the part of a JSON text at a path, as JSON.

No equivalent.

->>
^^^

.. code-block:: text

  json ->> path

Returns the part of a JSON text at a path, as an SQL value.

No equivalent.

json
^^^^

.. code-block:: text

  json(json)

Checks a JSON text and returns it without its extra whitespace.

No equivalent.

jsonb
^^^^^

.. code-block:: text

  jsonb(json)

Returns a JSON text in the binary JSONB form.

No equivalent.

jsonb_array
^^^^^^^^^^^

.. code-block:: text

  jsonb_array(value1, value2, ...)

Works like json_array, and returns JSONB.

No equivalent.

jsonb_array_insert
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_array_insert(json, path, value, ...)

Works like json_array_insert, and returns JSONB.

No equivalent.

jsonb_each
^^^^^^^^^^

.. code-block:: text

  jsonb_each(json, [path])

Works like json_each, with JSONB in the result.

No equivalent.

jsonb_extract
^^^^^^^^^^^^^

.. code-block:: text

  jsonb_extract(json, path, ...)

Works like json_extract, and returns JSONB for an array or object.

No equivalent.

jsonb_group_array
^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_group_array(value)

Works like json_group_array, and returns JSONB.

No equivalent.

jsonb_group_object
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_group_object(label, value)

Works like json_group_object, and returns JSONB.

No equivalent.

jsonb_insert
^^^^^^^^^^^^

.. code-block:: text

  jsonb_insert(json, path, value, ...)

Works like json_insert, and returns JSONB.

No equivalent.

jsonb_object
^^^^^^^^^^^^

.. code-block:: text

  jsonb_object(label1, value1, ...)

Works like json_object, and returns JSONB.

No equivalent.

jsonb_patch
^^^^^^^^^^^

.. code-block:: text

  jsonb_patch(json1, json2)

Works like json_patch, and returns JSONB.

No equivalent.

jsonb_remove
^^^^^^^^^^^^

.. code-block:: text

  jsonb_remove(json, path, ...)

Works like json_remove, and returns JSONB.

No equivalent.

jsonb_replace
^^^^^^^^^^^^^

.. code-block:: text

  jsonb_replace(json, path, value, ...)

Works like json_replace, and returns JSONB.

No equivalent.

jsonb_set
^^^^^^^^^

.. code-block:: text

  jsonb_set(json, path, value, ...)

Works like json_set, and returns JSONB.

No equivalent.

jsonb_tree
^^^^^^^^^^

.. code-block:: text

  jsonb_tree(json, [path])

Works like json_tree, with JSONB in the result.

No equivalent.

json_array
^^^^^^^^^^

Returns a JSON array of its arguments.

.. code-block:: sql

  -- json_array(value1, value2, ...)
  VALUES '[' || /*value1 as JSON*/ || ',' || /*value2 as JSON*/ || ']';
  -- SELECT json_array('A1', 10);
  VALUES '["' || 'A1' || '",' || CAST(10 AS VARCHAR(11)) || ']';
  -- COL1: ["A1",10]

A text needs double quotes around it, and it must not have a double quote,
a backslash or a control character in it, since nothing escapes them.

json_array_insert
^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_array_insert(json, path, value, ...)

Inserts values into a JSON array at the positions of the paths, moving the elements after them along.

No equivalent.

json_array_length
^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_array_length(json, [path])

Returns the number of elements of a JSON array.

No equivalent.

json_each
^^^^^^^^^

.. code-block:: text

  json_each(json, [path])

A table-valued function with a row for each element of a JSON array or object.

No equivalent.

json_error_position
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_error_position(json)

Returns the position of the first syntax error in a JSON text, or 0 when there's none.

No equivalent.

json_extract
^^^^^^^^^^^^

.. code-block:: text

  json_extract(json, path, ...)

Returns the values of a JSON text at one or more paths.

No equivalent.

json_group_array
^^^^^^^^^^^^^^^^

Returns a JSON array of the values of a column.

.. code-block:: sql

  -- json_group_array(value ORDER BY key)
  SELECT '[' || LISTAGG(/*value as JSON*/, ',') WITHIN GROUP (ORDER BY /*key*/) || ']' FROM /*table*/;
  -- SELECT json_group_array(name ORDER BY name) FROM products;
  SELECT '[' || LISTAGG('"' || name || '"', ',') WITHIN GROUP (ORDER BY name) || ']' FROM products;
  -- COL1: ["Apple","Banana","Cherry","Date"]

A text needs double quotes around it (see `json_array`_). ``LISTAGG`` leaves
out a ``NULL``, where SQLite adds a JSON ``null``.

json_group_object
^^^^^^^^^^^^^^^^^

Returns a JSON object with a label and a value from each row.

.. code-block:: sql

  -- json_group_object(label, value)
  SELECT '{' || LISTAGG('"' || /*label*/ || '":' || /*value as JSON*/, ',') WITHIN GROUP (ORDER BY /*key*/) || '}' FROM /*table*/;
  -- SELECT json_group_object(sku, price) FROM (SELECT * FROM products ORDER BY sku);
  SELECT '{' || LISTAGG('"' || sku || '":' || CAST(price AS VARCHAR(12)), ',') WITHIN GROUP (ORDER BY sku) || '}'
  FROM products;
  -- COL1: {"A1":1.50,"B2":0.25,"C3":4.00,"D4":3.00}

SQLite writes 4.00 as 4, since it stores the price as an integer, where
vsql keeps the decimal places of the column.

json_insert
^^^^^^^^^^^

.. code-block:: text

  json_insert(json, path, value, ...)

Adds values to a JSON text at paths that don't exist yet.

No equivalent.

json_object
^^^^^^^^^^^

Returns a JSON object of pairs of labels and values.

.. code-block:: sql

  -- json_object(label1, value1, ...)
  VALUES '{"' || /*label1*/ || '":' || /*value1 as JSON*/ || '}';
  -- SELECT json_object('sku', 'A1', 'qty', 10);
  VALUES '{"sku":"' || 'A1' || '","qty":' || CAST(10 AS VARCHAR(11)) || '}';
  -- COL1: {"sku":"A1","qty":10}

See `json_array`_ for the text values.

json_patch
^^^^^^^^^^

.. code-block:: text

  json_patch(json1, json2)

Merges one JSON object into another (an RFC 7396 merge patch).

No equivalent.

json_pretty
^^^^^^^^^^^

.. code-block:: text

  json_pretty(json, [indent])

Returns a JSON text laid out over several lines with indentation.

No equivalent.

json_quote
^^^^^^^^^^

Returns a value as JSON, such as a text in double quotes.

.. code-block:: sql

  -- json_quote(value)
  VALUES '"' || /*value*/ || '"';
  -- SELECT json_quote('Banana');
  VALUES '"' || 'Banana' || '"';
  -- COL1: "Banana"

Only for a text without a double quote, a backslash or a control character.
A number cast to text is already JSON.

json_remove
^^^^^^^^^^^

.. code-block:: text

  json_remove(json, path, ...)

Removes the parts of a JSON text at the paths.

No equivalent.

json_replace
^^^^^^^^^^^^

.. code-block:: text

  json_replace(json, path, value, ...)

Changes the values of a JSON text at paths that already exist.

No equivalent.

json_set
^^^^^^^^

.. code-block:: text

  json_set(json, path, value, ...)

Sets values of a JSON text at paths, whether they exist or not.

No equivalent.

json_tree
^^^^^^^^^

.. code-block:: text

  json_tree(json, [path])

A table-valued function with a row for every element of a JSON text, at every depth.

No equivalent.

json_type
^^^^^^^^^

.. code-block:: text

  json_type(json, [path])

Returns the type of a JSON value, such as object, array, text or integer.

No equivalent.

json_valid
^^^^^^^^^^

.. code-block:: text

  json_valid(json, [flags])

Tells whether a text (or blob) is well-formed JSON or JSONB.

No equivalent.
