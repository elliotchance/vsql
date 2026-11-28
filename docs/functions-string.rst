String Functions
================

.. contents::
   :local:
   :depth: 1

String functions accept a ``CHARACTER`` or ``CHARACTER VARYING`` (see
:doc:`text`), or a binary string (see :doc:`binary`) when the function says
so. A ``CHARACTER(n)`` value always has ``n`` characters, so its
padding spaces are counted and searched like any other character.

Lengths and positions are counted in characters, where a multibyte character
(such as ``😊``) counts as one, unless the function says otherwise. The first
character is at position 1.

BASE64_TO_BINARY
^^^^^^^^^^^^^^^^

.. code-block:: sql

   BASE64_TO_BINARY(string CHARACTER VARYING) BINARY VARYING
   BASE64_TO_BINARY(string CHARACTER LARGE OBJECT) BINARY LARGE OBJECT

Converts base64 (RFC 4648, with ``+`` and ``/``) to a binary string (see
:doc:`binary`). The ``=`` padding at the end is optional, and whitespace (such
as the line breaks that some other databases add) is ignored. Anything else,
including the URL-safe ``-`` and ``_``, is a ``22018`` error. It's the opposite
of ``BINARY_TO_BASE64``.

``BASE64_TO_BINARY`` is a vsql extension flagged by ``V406-04`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BASE64_TO_BINARY('TWFu');
  -- COL1: 4D616E

  VALUES BASE64_TO_BINARY('TQ');
  -- COL1: 4D

  VALUES BASE64_TO_BINARY('TW-u');
  -- error 22018: invalid character value for cast

**Compatibility**

- **SQL standard:** not standard. There's no ``CAST`` between a binary string
  and a character string.
- **Other databases:**

  - MySQL: ``FROM_BASE64``, invalid base64 is ``NULL``.
  - PostgreSQL: ``DECODE(value, 'base64')``.
  - SQLite and SQL Server: none built in.
  - Oracle: ``UTL_ENCODE.BASE64_DECODE``, of a ``RAW``.

BINARY_TO_BASE64
^^^^^^^^^^^^^^^^

.. code-block:: sql

   BINARY_TO_BASE64(octets BINARY VARYING) CHARACTER VARYING
   BINARY_TO_BASE64(octets BINARY LARGE OBJECT) CHARACTER LARGE OBJECT

Converts a binary string (see :doc:`binary`) to base64 (RFC 4648, with ``+``
and ``/``), 4 characters for every 3 octets, with ``=`` padding at the end and
no line breaks. A ``BINARY(n)`` includes its padding ``X'00'`` octets. A result
that's longer than 10485760 characters (the longest ``CHARACTER VARYING``) is a
``22001`` error. ``BASE64_TO_BINARY`` converts it back.

``BINARY_TO_BASE64`` is a vsql extension flagged by ``V406-03`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BINARY_TO_BASE64(X'4D616E');
  -- COL1: TWFu

  VALUES BINARY_TO_BASE64(X'4D');
  -- COL1: TQ==

**Compatibility**

- **SQL standard:** not standard. There's no ``CAST`` between a binary string
  and a character string.
- **Other databases:**

  - MySQL: ``TO_BASE64``, with a line break after every 76 characters.
  - PostgreSQL: ``ENCODE(value, 'base64')``, with a line break after every 76
    characters.
  - SQLite and SQL Server: none built in.
  - Oracle: ``UTL_ENCODE.BASE64_ENCODE``, which returns a ``RAW``.

BINARY_TO_HEX
^^^^^^^^^^^^^

.. code-block:: sql

   BINARY_TO_HEX(octets BINARY VARYING) CHARACTER VARYING
   BINARY_TO_HEX(octets BINARY LARGE OBJECT) CHARACTER LARGE OBJECT

Converts a binary string (see :doc:`binary`) to two upper case hexadecimal
digits for each octet, the same way that it's shown. A ``BINARY(n)`` includes
its padding ``X'00'`` octets. A result that's longer than 10485760 characters
(the longest ``CHARACTER VARYING``) is a ``22001`` error. ``HEX_TO_BINARY``
converts it back.

``BINARY_TO_HEX`` is a vsql extension flagged by ``V406-01`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BINARY_TO_HEX(X'CAFE');
  -- COL1: CAFE

  VALUES BINARY_TO_HEX(CAST(X'01' AS BINARY(3)));
  -- COL1: 010000

**Compatibility**

- **SQL standard:** not standard. There's no ``CAST`` between a binary string
  and a character string.
- **Other databases:**

  - MySQL and SQLite: ``HEX``. It also accepts a character string (its bytes)
    or a number.
  - PostgreSQL: ``ENCODE(value, 'hex')``, in lower case.
  - SQL Server: ``CONVERT(VARCHAR(MAX), value, 2)``.
  - Oracle: ``RAWTOHEX``.

BTRIM
^^^^^

.. code-block:: text

  BTRIM(STRING [, CHARACTERS ])

.. code-block:: sql

   BTRIM(CHARACTER VARYING(n), CHARACTER VARYING) CHARACTER VARYING(n)

Removes any of the ``CHARACTERS`` from both ends of ``STRING``. Unlike ``TRIM``,
``CHARACTERS`` can be any number of characters, and each one is removed
wherever it is in that part of the string. If it isn't provided, it's a space.
The result is a ``CHARACTER VARYING`` with the maximum length of ``STRING``.

`LTRIM`_ and `RTRIM`_ work the same way, but only remove characters from the
start or the end.

**Examples**

.. code-block:: sql

  VALUES BTRIM('  hello  ') || '|';
  -- COL1: hello|

  VALUES BTRIM('xyxhelloyx', 'xy');
  -- COL1: hello

**Compatibility**

- **SQL standard:** T056 (multi-character TRIM functions).
- **Other databases:** ``BTRIM`` in PostgreSQL.

CHAR_LENGTH
^^^^^^^^^^^

.. code-block:: text

   CHAR_LENGTH(STRING [ USING { CHARACTERS | OCTETS } ])

.. code-block:: sql

   CHAR_LENGTH(CHARACTER VARYING) INTEGER
   CHAR_LENGTH(CHARACTER LARGE OBJECT) INTEGER

Returns the number of characters (a multibyte character is counted as a single
character). The length of an empty string is 0, and the length of a
``CHARACTER(n)`` is ``n``, including the padding.

``USING CHARACTERS`` is the default. ``USING OCTETS`` counts the bytes of the
UTF-8 instead, like ``OCTET_LENGTH``.

**Examples**

.. code-block:: sql

  VALUES CHAR_LENGTH('😊£');
  -- COL1: 2

  VALUES CHAR_LENGTH(CAST('ab' AS CHARACTER(5)));
  -- COL1: 5

  VALUES CHAR_LENGTH('😊£' USING OCTETS);
  -- COL1: 6

**Compatibility**

- **SQL standard:** Core SQL (E021-04), including ``USING``.
- **Other databases:**

  - PostgreSQL: ``CHAR_LENGTH``, ``CHARACTER_LENGTH`` or ``LENGTH``, which don't
    count the padding of a ``CHARACTER``. None of them have ``USING``.
  - MySQL: ``CHAR_LENGTH`` or ``CHARACTER_LENGTH`` (``LENGTH`` is in bytes).
  - SQLite and Oracle: ``LENGTH``. vsql has ``LENGTH`` too, see `LENGTH`_.
  - SQL Server: ``LEN``, which doesn't count spaces at the end.

CHARACTER_LENGTH
^^^^^^^^^^^^^^^^

.. code-block:: sql

   CHARACTER_LENGTH(CHARACTER VARYING) INTEGER

``CHARACTER_LENGTH`` is another name for ``CHAR_LENGTH`` (including
``USING``), see ``CHAR_LENGTH``.

**Compatibility**

- **SQL standard:** Core SQL (E021-04).
- **Other databases:** see ``CHAR_LENGTH``.

CHR
^^^

.. code-block:: sql

   CHR(code_point BIGINT) CHARACTER VARYING(1)

The character with a Unicode code point, the opposite of ``UNICODE``. 0, a
negative number, a surrogate (``0xD800`` to ``0xDFFF``) or a number above
``0x10FFFF`` is a ``22023`` error (invalid parameter value), and a Unicode
noncharacter (such as ``0xFFFF``) is a ``22029`` error, the same as in a
``U&`` string.

``CHR`` is a vsql extension flagged by ``V404-05`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES CHR(65);
  -- COL1: A

  VALUES CHR(128522);
  -- COL1: 😊

  VALUES CHR(0);
  -- error 22023: invalid parameter value: CHR: 0 is not a valid Unicode code point

**Compatibility**

- **SQL standard:** not standard. A constant character can be written with a
  Unicode escape, such as ``U&'\+01F60A'`` (see :doc:`text`), but there's no
  standard function for a code point that isn't a constant.
- **Other databases:**

  - PostgreSQL and Oracle: ``CHR``.
  - MySQL: ``CHAR(n USING utf8mb4)``.
  - SQLite: ``CHAR``.
  - SQL Server: ``NCHAR``.

CONCAT
^^^^^^

.. code-block:: sql

   CONCAT(variadic ...) CHARACTER VARYING

Joins one or more character strings, in order, leaving out any that are
``NULL``. Unlike ``||``, a ``NULL`` doesn't make the result ``NULL``. If every
argument is ``NULL`` the result is an empty string.

The result is a ``CHARACTER VARYING`` as long as all of the arguments together,
or a ``CHARACTER LARGE OBJECT`` if any argument is one. A ``CHARACTER``
argument keeps its padding, like it does with ``||``. Every argument must be a
character string, so a number has to be ``CAST`` first, and a ``NULL`` has to
be ``CAST`` (such as ``CAST(NULL AS VARCHAR(10))``) as with any function. A
result that's longer than the maximum length of a ``CHARACTER VARYING`` is a
``22001`` error, unless only spaces would be cut from the end.

``CONCAT`` is a vsql extension flagged by ``V404-08`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES CONCAT('My', 'S', 'QL');
  -- COL1: MySQL

  VALUES CONCAT('abc', CAST(NULL AS VARCHAR(10)), 'xy');
  -- COL1: abcxy

  VALUES CONCAT('Total: ', CAST(42 AS VARCHAR(10)));
  -- COL1: Total: 42

**Compatibility**

- **SQL standard:** not standard. The standard ``||`` is ``NULL`` when either
  side is ``NULL``.
- **Other databases:** most have a ``CONCAT``, but they treat ``NULL``
  differently, and some convert other types to text:

  - PostgreSQL, SQL Server and SQLite: the same, a ``NULL`` is left out.
  - MySQL and MariaDB: the result is ``NULL`` if any argument is.
  - Oracle and Db2: only two arguments.

CONCAT_WS
^^^^^^^^^

.. code-block:: sql

   CONCAT_WS(separator CHARACTER VARYING, variadic ...) CHARACTER VARYING

Joins one or more character strings with the separator between them, leaving
out any that are ``NULL`` (and their separator), so there are never two
separators next to each other. If every value is ``NULL`` the result is an
empty string. If the separator is ``NULL``, the result is ``NULL``.

The type of the result, and the arguments it accepts, are the same as
``CONCAT``.

``CONCAT_WS`` is a vsql extension flagged by ``V404-09`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES CONCAT_WS(', ', 'a', 'b', 'c');
  -- COL1: a, b, c

  VALUES CONCAT_WS('-', 'a', CAST(NULL AS VARCHAR(10)), 'c');
  -- COL1: a-c

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL, MariaDB, PostgreSQL, SQL Server and SQLite: the same.
  - Snowflake: the result is ``NULL`` if any argument is.
  - Oracle, Db2 and BigQuery: no ``CONCAT_WS``.

ENDS_WITH
^^^^^^^^^

.. code-block:: sql

   ENDS_WITH(string CHARACTER VARYING, suffix CHARACTER VARYING) BOOLEAN
   ENDS_WITH(string BINARY VARYING, suffix BINARY VARYING) BOOLEAN

``TRUE`` if ``STRING`` ends with ``SUFFIX``. It works the same way as
`STARTS_WITH`_, but compares the end of the string.

``ENDS_WITH`` is a vsql extension flagged by ``V404-13`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES ENDS_WITH('report.csv', '.csv');
  -- COL1: TRUE

  VALUES ENDS_WITH(CAST('ab' AS CHARACTER(5)), 'b');
  -- COL1: FALSE

**Compatibility**

- **SQL standard:** not standard. ``LIKE`` works for a constant, but a suffix
  from a column or parameter needs its ``%``, ``_`` and escape characters to be
  escaped.
- **Other databases:**

  - BigQuery and DuckDB: ``ENDS_WITH``.
  - PostgreSQL: no equivalent.
  - Snowflake: ``ENDSWITH``, ClickHouse: ``endsWith``, Spark: ``endswith``.
  - MySQL, SQL Server, Oracle, SQLite and Db2: no equivalent.

FORMAT_SIZE
^^^^^^^^^^^

.. code-block:: sql

   FORMAT_SIZE(bytes NUMERIC) CHARACTER VARYING
   FORMAT_SIZE(bytes NUMERIC, significant_figures BIGINT) CHARACTER VARYING
   FORMAT_SIZE(bytes NUMERIC, significant_figures BIGINT, unit CHARACTER VARYING) CHARACTER VARYING
   FORMAT_SIZE(bytes NUMERIC, significant_figures BIGINT, unit CHARACTER VARYING, base BIGINT) CHARACTER VARYING

Formats a number of bytes as a size, such as ``24 MB``. Any exact number can be
used, and it's rounded to whole bytes.

Without a ``unit`` (or a ``NULL`` one), the size is in the largest decimal unit
that isn't more than the bytes, so the number is at least 1 and less than 1000:
``B``, ``kB``, ``MB``, ``GB``, ``TB``, ``PB``, ``EB``, ``ZB`` or ``YB`` (each
is 1000 of the one before it). A ``unit`` gives the result in that unit,
however big or small it is. It can be written in any way that ``PARSE_SIZE``
reads, including a binary unit (``KiB``, ``MiB`` to ``YiB``, each 1024 of the
one before it), and it's shown the standard way, such as ``MiB`` for
``'mebibytes'`` or ``kB`` for ``'KB'``. An unknown unit is a ``22023`` error.

``base`` (``0`` or ``NULL`` by default) is ``2`` for the largest binary unit
instead when there isn't a ``unit``, so the number is at least 1 and less than
1024: ``B``, ``KiB``, ``MiB`` to ``YiB``. ``10`` is the same as the default.
With a ``unit``, a ``base`` of ``2`` or ``10`` is used for it, the same as
``PARSE_SIZE``, so ``FORMAT_SIZE(24117248, 0, 'MB', 2)`` is ``23 MB`` (and
``PARSE_SIZE`` with the same ``base`` reads it back). It's a ``22023`` error if
the ``base`` isn't ``0``, ``2`` or ``10``.

``significant_figures`` (``0`` or ``NULL`` by default) is the most digits that
the number can have. The zeros at the end of a fraction aren't shown, so it's
``1.5 kB`` rather than ``1.50 kB``, and ``1 MB`` rather than ``1.00 MB``.
``0`` rounds to a whole number. The digits before the decimal point are never
rounded off, so 999 kB is ``999 kB`` with 2 significant figures, and bytes
never have a fraction. A number that's less than 1 (only with a ``unit``) is
rounded to the significant figures after its zeros, such as ``0.000488 MiB``. A
number is rounded to the nearest, with a half rounded away from zero. When that
makes it 1000 (or 1024 for a ``base`` of ``2``) without a ``unit``, it's 1 of
the next unit. It's a ``22023`` error
if ``significant_figures`` isn't from 0 to 20.

The result is ``NULL`` if ``bytes`` is ``NULL``. ``PARSE_SIZE`` converts a size
back to bytes.

``FORMAT_SIZE`` is a vsql extension flagged by ``V410-01`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES FORMAT_SIZE(24117248);
  -- COL1: 24 MB

  VALUES FORMAT_SIZE(1500);
  -- COL1: 2 kB

  VALUES FORMAT_SIZE(1500, 3);
  -- COL1: 1.5 kB

  VALUES FORMAT_SIZE(24117248, 3);
  -- COL1: 24.1 MB

  VALUES FORMAT_SIZE(999999);
  -- COL1: 1 MB

  VALUES FORMAT_SIZE(24117248, 3, CAST(NULL AS VARCHAR(3)), 2);
  -- COL1: 23 MiB

  VALUES FORMAT_SIZE(1048575, 0, CAST(NULL AS VARCHAR(3)), 2);
  -- COL1: 1 MiB

  VALUES FORMAT_SIZE(1073741824, 0, 'MiB');
  -- COL1: 1024 MiB

  VALUES FORMAT_SIZE(24117248, 0, 'MB', 2);
  -- COL1: 23 MB

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``pg_size_pretty``, which uses ``kB``, ``MB`` and so on for
    1024, only changes to the next unit at 10 of it, and doesn't have the
    significant figures or the unit. ``FORMAT_SIZE(x, 0, NULL, 2)`` is the
    closest, with the ``KiB`` names.
  - MySQL: ``FORMAT_BYTES`` (8.0.16), in ``KiB``, ``MiB`` and so on, with two
    decimal places, like a ``base`` of ``2``.
  - SQLite, SQL Server and Oracle: none.

HEX_TO_BINARY
^^^^^^^^^^^^^

.. code-block:: sql

   HEX_TO_BINARY(string CHARACTER VARYING) BINARY VARYING
   HEX_TO_BINARY(string CHARACTER LARGE OBJECT) BINARY LARGE OBJECT

Converts pairs of hexadecimal digits (in upper or lower case) to a binary
string (see :doc:`binary`), one octet for each pair. Anything else, including
an odd number of digits or spaces, is a ``22018`` error. It's the opposite of
``BINARY_TO_HEX``.

``HEX_TO_BINARY`` is a vsql extension flagged by ``V406-02`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES HEX_TO_BINARY('cafe');
  -- COL1: CAFE

  VALUES HEX_TO_BINARY('ABC');
  -- error 22018: invalid character value for cast

**Compatibility**

- **SQL standard:** not standard. There's no ``CAST`` between a binary string
  and a character string.
- **Other databases:**

  - MySQL: ``UNHEX``, an odd number of digits has a leading ``0`` and anything
    else is ``NULL``.
  - SQLite: ``UNHEX``, anything else is ``NULL``.
  - PostgreSQL: ``DECODE(value, 'hex')``.
  - SQL Server: ``CONVERT(VARBINARY(MAX), value, 2)``.
  - Oracle: ``HEXTORAW``.

INITCAP
^^^^^^^

.. code-block:: sql

   INITCAP(string CHARACTER VARYING) CHARACTER VARYING

Returns the string with the first letter of each word in upper case and the
rest in lower case. A word is a run of letters and digits, any other character
(such as a space, ``'`` or ``-``) starts a new word. The result has the same
type as the input, like ``UPPER`` and ``LOWER``, and uses the same full Unicode
case mappings, so it can also be truncated with a ``01004`` warning.

``INITCAP`` is a vsql extension flagged by ``V404-04`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES INITCAP('hELLO wORLD');
  -- COL1: Hello World

  VALUES INITCAP('o''neil mc-donald');
  -- COL1: O'Neil Mc-Donald

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL and Oracle: ``INITCAP``.
  - MySQL, SQLite and SQL Server: no equivalent.

LEFT
^^^^

.. code-block:: sql

   LEFT(string CHARACTER VARYING, n BIGINT) CHARACTER VARYING
   LEFT(string CHARACTER LARGE OBJECT, n BIGINT) CHARACTER LARGE OBJECT
   LEFT(string BINARY VARYING, n BIGINT) BINARY VARYING
   LEFT(string BINARY LARGE OBJECT, n BIGINT) BINARY LARGE OBJECT

Returns the first ``n`` characters of a string, or the whole string if it's
shorter. A negative ``n`` returns all but the last ``-n`` characters, which is
an empty string when the string isn't longer than ``-n``. A binary string (see
:doc:`binary`) is counted in octets.

The result is a varying string with the length of the argument, like
``SUBSTRING``, so a ``CHARACTER(5)`` is a ``CHARACTER VARYING(5)``. Its padding
is kept. A large object stays a large object. See also ``RIGHT``.

``LEFT`` is a vsql extension flagged by ``V404-16`` (see :doc:`sql-flagging`).
``LEFT`` is still a join (as in ``LEFT JOIN``), since a join is never followed
by ``(``.

**Examples**

.. code-block:: sql

  VALUES LEFT('hello', 2);
  -- COL1: he

  VALUES LEFT('hello', -2);
  -- COL1: hel

  VALUES LEFT('😊£ab', 10);
  -- COL1: 😊£ab

  VALUES LEFT(X'010203', 1);
  -- COL1: 01

**Compatibility**

- **SQL standard:** not standard. Use ``SUBSTRING``.
- **Other databases:**

  - PostgreSQL and DuckDB: ``LEFT`` and ``RIGHT``, with the same negative
    ``n``.
  - MySQL, MariaDB, SQL Server and Snowflake: ``LEFT`` and ``RIGHT``, where a
    negative ``n`` is an empty string (or an error in SQL Server).
  - SQLite and Oracle: no equivalent, use ``SUBSTR``.

LENGTH
^^^^^^

.. code-block:: sql

   LENGTH(string CHARACTER VARYING) INTEGER
   LENGTH(string BINARY VARYING) INTEGER
   LENGTH(string BINARY LARGE OBJECT) INTEGER

``LENGTH`` is another name for ``CHAR_LENGTH``: the number of characters, where
a multibyte character counts as one. Spaces at the end are counted, and so is
the padding of a ``CHARACTER(n)``. The length of an empty string is 0.

The length of a binary string (see :doc:`binary`) is its number of octets, the
same as ``OCTET_LENGTH``.

``LENGTH`` is a vsql extension flagged by ``V404-10`` (see
:doc:`sql-flagging`). The standard name is ``CHAR_LENGTH``.

**Examples**

.. code-block:: sql

  VALUES LENGTH('hello');
  -- COL1: 5

  VALUES LENGTH('😊£');
  -- COL1: 2

  VALUES LENGTH(X'010203');
  -- COL1: 3

**Compatibility**

- **SQL standard:** not standard, use ``CHAR_LENGTH`` (or ``OCTET_LENGTH`` for
  a binary string).
- **Other databases:**

  - PostgreSQL, SQLite, Oracle, Db2 and DuckDB: the same, but PostgreSQL
    doesn't count the padding of a ``CHARACTER``.
  - MySQL and MariaDB: ``LENGTH`` is the number of bytes, which is
    ``OCTET_LENGTH`` in vsql.
  - SQL Server: ``LEN``, which doesn't count spaces at the end.

LOWER
^^^^^

.. code-block:: sql

   LOWER(CHARACTER VARYING) CHARACTER VARYING
   LOWER(CHARACTER LARGE OBJECT) CHARACTER LARGE OBJECT

Returns the input string converted to lower-case. The result has the same type
as the input, such as ``CHARACTER(5)`` for ``LOWER('Hello')``.

The full Unicode case mappings are used, so a character may become several
characters. A result that's longer than the maximum length of the type is
truncated, with a warning (``01004``) if any of the removed characters aren't
spaces. See ``UPPER`` for an example.

**Examples**

.. code-block:: sql

  VALUES LOWER('Hello');
  -- COL1: hello

  VALUES LOWER('ÀÉ');
  -- COL1: àé

**Compatibility**

- **SQL standard:** Core SQL (E021-08).
- **Other databases:** ``LOWER`` in all of them, and ``LCASE`` in MySQL. SQLite
  only converts ASCII letters (unless it's built with ICU).

LPAD
^^^^

.. code-block:: text

  LPAD(STRING, LENGTH [, PADDING ])

.. code-block:: sql

   LPAD(CHARACTER VARYING, INTEGER, CHARACTER VARYING) CHARACTER VARYING

Pads the start of ``STRING`` to ``LENGTH`` characters. ``PADDING`` is repeated
as many times as it fits, and the last one is cut short. If it isn't provided,
it's a space, and if it's empty, nothing is added.

If ``STRING`` is already longer, it's cut to ``LENGTH`` characters by removing
characters from the end. A ``LENGTH`` of less than 1 is an empty string.
``LENGTH`` must be an exact number without a scale, such as an ``INTEGER``.

`RPAD`_ works the same way, but pads the end.

**Examples**

.. code-block:: sql

  VALUES LPAD('42', 5, '0');
  -- COL1: 00042

  VALUES LPAD('abcdef', 3);
  -- COL1: abc

**Compatibility**

- **SQL standard:** T055 (string padding functions).
- **Other databases:** ``LPAD`` in PostgreSQL, MySQL and Oracle.

LTRIM
^^^^^

.. code-block:: text

  LTRIM(STRING [, CHARACTERS ])

.. code-block:: sql

   LTRIM(CHARACTER VARYING(n), CHARACTER VARYING) CHARACTER VARYING(n)

Works like `BTRIM`_, but only removes the ``CHARACTERS`` from the start of
``STRING``.

**Examples**

.. code-block:: sql

  VALUES LTRIM('  hello  ') || '|';
  -- COL1: hello  |

  VALUES LTRIM('xyxhelloyx', 'xy');
  -- COL1: helloyx

**Compatibility**

- **SQL standard:** T056 (multi-character TRIM functions).
- **Other databases:** ``LTRIM`` in PostgreSQL, SQLite and Oracle. MySQL and
  SQL Server only remove spaces.

OCTET_LENGTH
^^^^^^^^^^^^

.. code-block:: sql

   OCTET_LENGTH(CHARACTER VARYING) INTEGER
   OCTET_LENGTH(BINARY VARYING) INTEGER
   OCTET_LENGTH(BINARY LARGE OBJECT) INTEGER
   OCTET_LENGTH(CHARACTER LARGE OBJECT) INTEGER

Returns the length in bytes, which is the length of the string encoded as
UTF-8. A character can be 1 to 4 bytes. For a binary string (see
:doc:`binary`), it's the number of octets. The length of a large value is known
without reading it.

**Examples**

.. code-block:: sql

  VALUES OCTET_LENGTH('😊£');
  -- COL1: 6

  VALUES OCTET_LENGTH('abc');
  -- COL1: 3

**Compatibility**

- **SQL standard:** Core SQL (E021-05).
- **Other databases:**

  - PostgreSQL and SQLite: ``OCTET_LENGTH``.
  - MySQL: ``OCTET_LENGTH`` or ``LENGTH``.
  - SQL Server: ``DATALENGTH``, which is the length in the encoding of the
    value.
  - Oracle: ``LENGTHB``.

OVERLAY
^^^^^^^

.. code-block:: text

   OVERLAY(
     STRING
     PLACING REPLACEMENT
     FROM START
     [ FOR LENGTH ]
     [ USING { CHARACTERS | OCTETS } ]
   )

.. code-block:: sql

   OVERLAY(CHARACTER VARYING(n) PLACING CHARACTER VARYING(m) FROM INTEGER) CHARACTER VARYING(2n + m)
   OVERLAY(CHARACTER VARYING(n) PLACING CHARACTER VARYING(m) FROM INTEGER FOR INTEGER) CHARACTER VARYING(2n + m)

Replaces ``LENGTH`` characters of ``STRING``, starting at ``START``, with
``REPLACEMENT``. ``REPLACEMENT`` can be shorter or longer than the part it
replaces, so the string can shrink or grow. If ``LENGTH`` is not provided, it's
the length of ``REPLACEMENT``, so the same number of characters are
overwritten.

``OVERLAY`` is defined by the SQL standard as:

.. code-block:: sql

  SUBSTRING(STRING FROM 1 FOR START - 1)
    || REPLACEMENT
    || SUBSTRING(STRING FROM START + LENGTH)

So it follows the same rules as ``SUBSTRING`` and ``||``:

- A ``LENGTH`` of 0 inserts ``REPLACEMENT`` before ``START``, and an empty
  ``REPLACEMENT`` deletes the characters.
- A ``START`` after the end of ``STRING`` appends ``REPLACEMENT``, and a
  ``LENGTH`` that goes past the end replaces the rest of ``STRING``.
- A ``START`` before 1 is a ``22011`` error (substring error), because the first
  ``SUBSTRING`` has a negative length.
- A negative ``LENGTH`` isn't an error, the rest of ``STRING`` starts earlier
  and repeats some characters. So ``OVERLAY('abcdef' PLACING 'X' FROM 3 FOR -1)``
  is ``'abXbcdef'``.
- ``START`` and ``LENGTH`` must be integers (or a ``NUMERIC`` or ``DECIMAL``
  with a scale of 0), otherwise it's a ``42601`` error.
- The result is a ``CHARACTER VARYING`` that's long enough for both
  ``SUBSTRING`` results and ``REPLACEMENT``, even though the value can never be
  that long.

``USING CHARACTERS`` (the default) counts ``START`` and ``LENGTH`` in
characters, and ``USING OCTETS`` counts them in bytes, like ``SUBSTRING``.
Without ``FOR``, ``USING OCTETS`` replaces as many bytes as there are in
``REPLACEMENT``.

``STRING`` and ``REPLACEMENT`` can also both be binary strings (see
:doc:`binary`), which are counted in octets and can't have ``USING``. The
result is a ``BINARY VARYING`` (or a ``BINARY LARGE OBJECT`` if either one is).

**Examples**

.. code-block:: sql

  VALUES OVERLAY('Hello World' PLACING 'There' FROM 7);
  -- COL1: Hello There

  VALUES OVERLAY('Hello World' PLACING 'Big ' FROM 7 FOR 0);
  -- COL1: Hello Big World

  VALUES OVERLAY('Hello World' PLACING '' FROM 6 FOR 6);
  -- COL1: Hello

  VALUES OVERLAY('abc' PLACING 'XYZ' FROM 2);
  -- COL1: aXYZ

  VALUES OVERLAY('abc' PLACING 'X' FROM 10);
  -- COL1: abcX

  VALUES OVERLAY('abc' PLACING 'X' FROM 0);
  -- error 22011: substring error

**Compatibility**

- **SQL standard:** T312 (OVERLAY function). ``USING`` is part of T061 (UCS
  support).
- **Other databases:**

  - PostgreSQL: ``OVERLAY``, with the same syntax (without ``USING``).
  - MySQL: ``INSERT(string, start, length, replacement)``. The ``LENGTH`` is
    required, and a ``START`` outside of the string returns ``STRING``
    unchanged.
  - SQL Server: ``STUFF(string, start, length, replacement)``. The ``LENGTH``
    is required, and a ``START`` outside of the string returns ``NULL``.
  - SQLite and Oracle: ``SUBSTR(...) || replacement || SUBSTR(...)``.

PARSE_SIZE
^^^^^^^^^^

.. code-block:: sql

   PARSE_SIZE(size CHARACTER VARYING) BIGINT
   PARSE_SIZE(size CHARACTER VARYING, base BIGINT) BIGINT

Converts a size, such as ``'23 MiB'``, to a number of bytes, rounded to a whole
number (with a half rounded away from zero).

The number can have a sign, a fraction and an exponent, such as ``-1.5e3``. Its
digits can be grouped by an underscore anywhere between two of them
(``1_048_576``), or by commas in groups of three (``1,048,576``), so ``1,5`` is
an error rather than ``15``.

The unit is in upper or lower case, and can be nothing (bytes), ``B``,
``BYTE`` or ``BYTES``, or for each of kilo, mega, giga, tera, peta, exa, zetta
and yotta (``K``, ``M``, ``G``, ``T``, ``P``, ``E``, ``Z`` and ``Y``):

- A decimal unit: ``K``, ``KB`` or ``KILOBYTE(S)``, which is 1000 (and 1000 to
  the power of each one after it).
- A binary unit: ``KI``, ``KIB`` or ``KIBIBYTE(S)``, which is 1024 (and 1024 to
  the power of each one after it).

There can be any white space before, between and after the number and the
unit. An ``E`` that's followed by a digit is an exponent, otherwise it's the
unit (``1EB`` is 1 exabyte).

``base`` (``0`` or ``NULL`` by default) decides the unit from its name, as above.
``2`` or ``10`` is used for every unit instead (1024 or 1000), whatever it's
called, for a system that's known to name its units wrongly (such as ``MB`` for
1024 KiB). Bytes are always bytes. It's a ``22023`` error if the ``base`` isn't
``0``, ``2`` or ``10``.

It's a ``22018`` error if the size can't be read, and a ``22003`` error if it's
more than a ``BIGINT``. The result is ``NULL`` if ``size`` is ``NULL``.
``FORMAT_SIZE`` formats a number of bytes as a size.

``PARSE_SIZE`` is a vsql extension flagged by ``V410-02`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES PARSE_SIZE('23 MiB');
  -- COL1: 24117248

  VALUES PARSE_SIZE('  23mib ');
  -- COL1: 24117248

  VALUES PARSE_SIZE('23 MB');
  -- COL1: 23000000

  VALUES PARSE_SIZE('23 MiB', 10);
  -- COL1: 23000000

  VALUES PARSE_SIZE('23 MB', 2);
  -- COL1: 24117248

  VALUES PARSE_SIZE('1,024 KiB');
  -- COL1: 1048576

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``pg_size_bytes``, where ``kB``, ``MB`` and so on are 1024.
  - MySQL, SQLite, SQL Server and Oracle: none.

POSITION
^^^^^^^^

.. code-block:: text

   POSITION(SEARCH IN STRING [ USING { CHARACTERS | OCTETS } ])

.. code-block:: sql

   POSITION(CHARACTER VARYING IN CHARACTER VARYING) INTEGER
   POSITION(BINARY VARYING IN BINARY VARYING) INTEGER

``POSITION(SEARCH IN STRING)`` returns the start of the left most (first)
match of ``SEARCH`` within ``STRING``. 1 will be the smallest index on a match and 0 is returned if
``SEARCH`` does not exist in ``STRING``. The position is counted in characters
(a multibyte character counts as one), unless it's ``USING OCTETS``, which
counts the bytes of the UTF-8.

Matching is case-sensitive. An empty ``SEARCH`` is found at the start of any
``STRING`` (even an empty one), so the result is 1.

``SEARCH`` and ``STRING`` can also both be binary strings (see :doc:`binary`),
including a ``BINARY LARGE OBJECT``, and then the position is counted in
octets and can't have ``USING``.

**Examples**

.. code-block:: sql

  VALUES POSITION('He' IN 'hello Hello');
  -- COL1: 7

  VALUES POSITION('xx' IN 'hello Hello');
  -- COL1: 0

  VALUES POSITION('£' IN '😊£');
  -- COL1: 2

  VALUES POSITION('£' IN '😊£' USING OCTETS);
  -- COL1: 5

**Compatibility**

- **SQL standard:** Core SQL (E021-11), including ``USING``.
- **Other databases:**

  - PostgreSQL: ``POSITION(search IN string)`` or ``STRPOS(string, search)``.
  - MySQL: ``POSITION(search IN string)``, ``LOCATE(search, string)`` or
    ``INSTR(string, search)``.
  - SQLite and Oracle: ``INSTR(string, search)``.
  - SQL Server: ``CHARINDEX(search, string)``.

QUOTE
^^^^^

.. code-block:: sql

   QUOTE(value) CHARACTER VARYING

Returns an SQL literal that results in the same value, and the same kind of
type, when it's used in a statement. It's for building SQL, such as an
``INSERT`` for each row of a table:

.. list-table::
  :header-rows: 1

  * - Value
    - Result

  * - Character string
    - ``'O''Reilly'``: in single quotes, with each ``'`` doubled. The padding
      of a ``CHARACTER(n)`` is kept, and other characters are kept as they are.

  * - Exact number
    - ``42``, ``-7`` or ``1.50``, with the scale of the value.

  * - ``REAL`` or ``DOUBLE PRECISION``
    - ``1.5e0``, the shortest form that results in the same number, with an
      exponent so that it's approximate.

  * - ``DECFLOAT``
    - ``CAST('1.5' AS DECFLOAT(34))``, since there's no ``DECFLOAT`` literal.

  * - ``BOOLEAN``
    - ``TRUE`` or ``FALSE``.

  * - Date, time or timestamp
    - ``DATE '2026-11-17'``, ``TIME '12:30:00'`` or
      ``TIMESTAMP '2026-11-17 12:30:00.123456+10:00'``.

  * - Interval
    - ``INTERVAL '1-02' YEAR(2) TO MONTH``.

  * - Binary string
    - ``X'DEADBEEF'``.

  * - ``NULL`` of any type
    - ``NULL``, the word, not a ``NULL`` value.

The result is a ``CHARACTER VARYING``, or a ``CHARACTER LARGE OBJECT`` for a
``CHARACTER LARGE OBJECT`` or ``BINARY LARGE OBJECT``.

The value is the same, but the declared type might not be: ``QUOTE`` of a
``SMALLINT`` is an ``INTEGER`` literal, and ``NULL`` has no type. That doesn't
matter in an ``INSERT`` or ``UPDATE``, because the value is stored as the type
of the column.

``QUOTE`` is a vsql extension flagged by ``V404-14`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES QUOTE('O''Reilly');
  -- COL1: 'O''Reilly'

  VALUES QUOTE(42);
  -- COL1: 42

  VALUES QUOTE(DATE '2026-11-17');
  -- COL1: DATE '2026-11-17'

  VALUES QUOTE(CAST(NULL AS INTEGER));
  -- COL1: NULL

  VALUES 'INSERT INTO t VALUES (' || QUOTE(1) || ', ' || QUOTE('a''b') || ');';
  -- COL1: INSERT INTO t VALUES (1, 'a''b');

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - SQLite: ``quote``, the same for the types that SQLite has.
  - MySQL: ``QUOTE``, which escapes with a backslash, and only for strings.
  - PostgreSQL: ``quote_nullable``, which is always a string literal (such as
    ``'42'``), and ``quote_literal``, which is ``NULL`` for ``NULL``.

QUOTE_IDENT
^^^^^^^^^^^

.. code-block:: sql

   QUOTE_IDENT(name CHARACTER VARYING) CHARACTER VARYING

Returns a delimited identifier: the name in double quotes, with each ``"``
doubled. It always adds the quotes, so the name keeps its case (a name that
isn't quoted is upper case) and can be a reserved word. A qualified name isn't
split, so ``QUOTE_IDENT('s.t')`` is ``"s.t"``, which is one name. Use
``QUOTE_IDENT(s) || '.' || QUOTE_IDENT(t)`` instead.

If the name is ``NULL``, the result is ``NULL``. An empty name is a ``22023``
error (invalid parameter value), because an identifier can't be empty.

``QUOTE_IDENT`` is a vsql extension flagged by ``V404-15`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES QUOTE_IDENT('Order Details');
  -- COL1: "Order Details"

  VALUES QUOTE_IDENT('a"b');
  -- COL1: "a""b"

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``quote_ident``, which only adds the quotes when they're
    needed.
  - SQL Server: ``QUOTENAME``, with ``[ ]``.
  - MySQL: ``sys.quote_identifier``, with backticks.

REPEAT
^^^^^^

.. code-block:: sql

   REPEAT(string CHARACTER VARYING, n BIGINT) CHARACTER VARYING

Returns the string repeated ``n`` times, or an empty string if ``n`` is 0 or
less. The padding of a ``CHARACTER(n)`` is repeated too. The result is a
``CHARACTER VARYING`` without a maximum length, but one that would be longer
than 10485760 characters is a ``22001`` error.

``REPEAT`` is a vsql extension flagged by ``V404-03`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES REPEAT('ab', 3);
  -- COL1: ababab

  VALUES REPEAT('ab', 0);
  -- COL1:

**Compatibility**

- **SQL standard:** not standard. When the length of the result is known, a
  string of one repeated character can be made with `RPAD`_ (T055).
- **Other databases:**

  - PostgreSQL and MySQL: ``REPEAT``.
  - SQL Server: ``REPLICATE``.
  - Oracle: ``RPAD('', n * LENGTH(s), s)``.
  - SQLite: no equivalent.

REPLACE
^^^^^^^

.. code-block:: sql

   REPLACE(string CHARACTER VARYING, target CHARACTER VARYING, replacement CHARACTER VARYING) CHARACTER VARYING

``REPLACE(STRING, FROM, TO)`` replaces every occurrence of ``FROM`` in
``STRING`` with ``TO``. The occurrences are found from left to right and don't
overlap, so ``REPLACE('aaa', 'aa', 'b')`` is ``'ba'``. Matching is
case-sensitive and compares characters, not bytes.

An empty ``FROM`` returns ``STRING`` unchanged, and an empty ``TO`` removes
each occurrence. The result is ``NULL`` if any argument is ``NULL``.

The padding of a ``CHARACTER(n)`` is searched like any other character. The
result is a ``CHARACTER VARYING`` without a maximum length, because it can be
longer than ``STRING``.

``REPLACE`` is a vsql extension flagged by ``V404-02`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES REPLACE('a.b.c', '.', '::');
  -- COL1: a::b::c

  VALUES REPLACE('aaa', 'aa', 'b');
  -- COL1: ba

  VALUES REPLACE('Hello hello', 'hello', 'bye');
  -- COL1: Hello bye

  VALUES REPLACE('banana', 'an', '');
  -- COL1: ba

**Compatibility**

- **SQL standard:** not standard. The standard way is ``TRANSLATE_REGEX``
  (F845), which vsql doesn't support yet (see
  `#1471 <https://github.com/elliotchance/vsql/issues/1471>`_). Its search is a
  regular expression, so any special characters in ``FROM`` (such as ``.`` or
  ``*``) have to be escaped.
- **Other databases:** ``REPLACE`` in all of them. SQL Server's matching
  follows the collation, so it's usually case-insensitive. In Oracle a ``NULL``
  (or empty) ``FROM`` or ``TO`` isn't ``NULL``, it's treated like an empty
  string.

REVERSE
^^^^^^^

.. code-block:: sql

   REVERSE(string CHARACTER VARYING) CHARACTER VARYING
   REVERSE(string BINARY VARYING) BINARY VARYING
   REVERSE(string BINARY LARGE OBJECT) BINARY LARGE OBJECT

Returns the characters of a string in the opposite order. A binary string (see
:doc:`binary`) is reversed by octet. The result has the same type as the
argument, so the padding of a ``CHARACTER(n)`` ends up at the start.

A character string is reversed by Unicode code point, not by what's seen as a
single character (a grapheme cluster). A character that's made of more than
one code point doesn't survive the reversal: an ``e`` followed by a combining
accent (U+0301) ends up with the accent on the wrong letter, and emoji that are
joined (with U+200D) or flags (two regional indicators) are split up.

``REVERSE`` is a vsql extension flagged by ``V404-11`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES REVERSE('hello');
  -- COL1: olleh

  VALUES REVERSE('😊£');
  -- COL1: £😊

  VALUES REVERSE(X'010203');
  -- COL1: 030201

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL, MySQL, MariaDB, SQL Server, Snowflake and DuckDB: ``REVERSE``
    of a character string, by code point.
  - BigQuery and ClickHouse: also for a binary string, by byte.
  - SQLite and Db2: no equivalent.

RIGHT
^^^^^

.. code-block:: sql

   RIGHT(string CHARACTER VARYING, n BIGINT) CHARACTER VARYING
   RIGHT(string CHARACTER LARGE OBJECT, n BIGINT) CHARACTER LARGE OBJECT
   RIGHT(string BINARY VARYING, n BIGINT) BINARY VARYING
   RIGHT(string BINARY LARGE OBJECT, n BIGINT) BINARY LARGE OBJECT

Returns the last ``n`` characters of a string, or the whole string if it's
shorter. A negative ``n`` returns all but the first ``-n`` characters. It has
the same types as ``LEFT``.

``RIGHT`` is a vsql extension flagged by ``V404-17`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES RIGHT('hello', 3);
  -- COL1: llo

  VALUES RIGHT('hello', -2);
  -- COL1: llo

  VALUES RIGHT(X'010203', 1);
  -- COL1: 03

**Compatibility**

- **SQL standard:** not standard. Use ``SUBSTRING``.
- **Other databases:**

  - PostgreSQL and DuckDB: ``LEFT`` and ``RIGHT``, with the same negative
    ``n``.
  - MySQL, MariaDB, SQL Server and Snowflake: ``LEFT`` and ``RIGHT``, where a
    negative ``n`` is an empty string (or an error in SQL Server).
  - SQLite and Oracle: no equivalent, use ``SUBSTR``.

RPAD
^^^^

.. code-block:: text

  RPAD(STRING, LENGTH [, PADDING ])

.. code-block:: sql

   RPAD(CHARACTER VARYING, INTEGER, CHARACTER VARYING) CHARACTER VARYING

Works like `LPAD`_, but pads the end of ``STRING``. A ``STRING`` that is
already longer is still cut by removing characters from the end.

**Examples**

.. code-block:: sql

  VALUES RPAD('abc', 8, 'xy');
  -- COL1: abcxyxyx

  VALUES RPAD('abcdef', 3);
  -- COL1: abc

**Compatibility**

- **SQL standard:** T055 (string padding functions).
- **Other databases:** ``RPAD`` in PostgreSQL, MySQL and Oracle.

RTRIM
^^^^^

.. code-block:: text

  RTRIM(STRING [, CHARACTERS ])

.. code-block:: sql

   RTRIM(CHARACTER VARYING(n), CHARACTER VARYING) CHARACTER VARYING(n)

Works like `BTRIM`_, but only removes the ``CHARACTERS`` from the end of
``STRING``.

**Examples**

.. code-block:: sql

  VALUES '|' || RTRIM('  hello  ');
  -- COL1: |  hello

  VALUES RTRIM('hello!?!', '?!');
  -- COL1: hello

**Compatibility**

- **SQL standard:** T056 (multi-character TRIM functions).
- **Other databases:** ``RTRIM`` in PostgreSQL, SQLite and Oracle. MySQL and
  SQL Server only remove spaces.

SPLIT_PART
^^^^^^^^^^

.. code-block:: sql

   SPLIT_PART(string CHARACTER VARYING, delimiter CHARACTER VARYING, n BIGINT) CHARACTER VARYING

``SPLIT_PART(STRING, DELIMITER, N)`` splits ``STRING`` on every ``DELIMITER``
and returns field ``N``, where the first field is 1. A negative ``N`` counts
from the end, so -1 is the last field. A field that doesn't exist is an empty
string, and ``N`` = 0 is a ``22023`` error.

The delimiter is matched as plain text, case-sensitive. An empty delimiter
doesn't split the string, so it's the only field. The result is a
``CHARACTER VARYING`` with the length of ``STRING``, like ``SUBSTRING``.

``SPLIT_PART`` is a vsql extension flagged by ``V404-07`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES SPLIT_PART('a,b,c', ',', 2);
  -- COL1: b

  VALUES SPLIT_PART('a,b,c', ',', -1);
  -- COL1: c

  VALUES SPLIT_PART('a,b,c', ',', 4);
  -- COL1:

**Compatibility**

- **SQL standard:** not standard. The standard way is ``SUBSTRING_REGEX`` with
  ``OCCURRENCE`` (F844), which vsql doesn't support yet (see
  `#1185 <https://github.com/elliotchance/vsql/issues/1185>`_).
- **Other databases:**

  - PostgreSQL: ``SPLIT_PART``.
  - MySQL: ``SUBSTRING_INDEX(SUBSTRING_INDEX(s, d, n), d, -1)``.
  - Oracle: ``REGEXP_SUBSTR``.
  - SQL Server: ``STRING_SPLIT``, which returns a table.
  - SQLite: no equivalent.

STARTS_WITH
^^^^^^^^^^^

.. code-block:: sql

   STARTS_WITH(string CHARACTER VARYING, prefix CHARACTER VARYING) BOOLEAN
   STARTS_WITH(string BINARY VARYING, prefix BINARY VARYING) BOOLEAN

``TRUE`` if ``STRING`` starts with ``PREFIX``. Unlike ``LIKE``, no character is
special, so ``%`` and ``_`` are only themselves. An empty prefix is always
``TRUE``, and a prefix that's longer than the string is ``FALSE``. If either
argument is ``NULL``, the result is ``NULL``.

The comparison is exact, by code point, and case-sensitive. Unlike ``=``,
nothing is padded with spaces, so spaces at the end, and the padding of a
``CHARACTER(n)``, count (see :doc:`text`). Both arguments can also be binary
strings (see :doc:`binary`), which are compared by octet.

``STARTS_WITH`` is a vsql extension flagged by ``V404-12`` (see
:doc:`sql-flagging`). It can't use an index yet.

**Examples**

.. code-block:: sql

  VALUES STARTS_WITH('hello world', 'hello');
  -- COL1: TRUE

  VALUES STARTS_WITH('100%', '100%');
  -- COL1: TRUE

  VALUES STARTS_WITH('1000', '10%');
  -- COL1: FALSE

  VALUES STARTS_WITH(X'010203', X'0102');
  -- COL1: TRUE

**Compatibility**

- **SQL standard:** not standard. ``LIKE`` works for a constant, but a prefix
  from a column or parameter needs its ``%``, ``_`` and escape characters to be
  escaped.
- **Other databases:**

  - BigQuery and DuckDB: ``STARTS_WITH``.
  - PostgreSQL: ``starts_with`` or the ``^@`` operator.
  - Snowflake: ``STARTSWITH``, ClickHouse: ``startsWith``, Spark: ``startswith``.
  - MySQL, SQL Server, Oracle, SQLite and Db2: no equivalent.

SUBSTRING
^^^^^^^^^

.. code-block:: text

   SUBSTRING(
     STRING
     FROM START
     [ FOR LENGTH ]
     [ USING { CHARACTERS | OCTETS } ]
   )

   SUBSTRING(STRING SIMILAR PATTERN ESCAPE ESCAPE_CHARACTER)

.. code-block:: sql

   SUBSTRING(CHARACTER VARYING(n) FROM INTEGER) CHARACTER VARYING(n)
   SUBSTRING(CHARACTER VARYING(n) FROM INTEGER FOR INTEGER) CHARACTER VARYING(n)
   SUBSTRING(CHARACTER VARYING(n) SIMILAR CHARACTER VARYING ESCAPE CHARACTER) CHARACTER VARYING(n)
   SUBSTRING(BINARY VARYING(n) FROM INTEGER [ FOR INTEGER ]) BINARY VARYING(n)
   SUBSTRING(BINARY LARGE OBJECT(n) FROM INTEGER [ FOR INTEGER ]) BINARY LARGE OBJECT(n)

Returns part of ``STRING``. The result is a ``CHARACTER VARYING`` with the
maximum length of ``STRING``.

``START`` starts at 1 for the first character or byte. If ``START`` is after
the end the returned value will be empty.

If ``LENGTH`` is not provided, all characters or bytes until the end will be
included. Otherwise, only ``LENGTH`` will be included. If ``LENGTH`` goes
beyond the end of the string it will only be used until the end. ``LENGTH``
must not be negative, otherwise a ``22011`` error (substring error) is raised.

``START`` and ``LENGTH`` must be integers (or a ``NUMERIC`` or ``DECIMAL`` with
a scale of 0), so ``SUBSTRING('hello' FROM 2.5)`` is an error. A dynamic
parameter (``?``) can be any number that's a whole number.

A ``START`` before 1 is allowed, but the positions before the first character
still count towards ``LENGTH``. So ``SUBSTRING('hello' FROM 0 FOR 3)`` is
``'he'``, and ``SUBSTRING('hello' FROM -5 FOR 3)`` is empty.

If ``CHARACTERS`` is specified ``START`` and ``LENGTH`` will count in characters
(this works with multibyte characters) whereas ``OCTETS`` will strictly count
in bytes. If ``USING`` is not provided, ``CHARACTERS`` will be used.

``STRING`` can also be a binary string (see :doc:`binary`), which is counted in
octets and can't have ``USING``. The result is a ``BINARY VARYING`` with the
maximum length of ``STRING``, or a ``BINARY LARGE OBJECT`` for one, which only
reads the octets of a large value that are in the result.

With ``SIMILAR``, the part of ``STRING`` that is returned is found with a
pattern instead. ``PATTERN`` must have exactly two of ``ESCAPE_CHARACTER``
followed by a double quote (``"``), otherwise a ``2200C`` error (invalid use of
escape character) is raised. They split it into three patterns, and the whole
of ``STRING`` must match all three together, the same as ``SIMILAR TO`` (see
:doc:`expressions`). The result is the part that matches the middle pattern,
or ``NULL`` if ``STRING`` doesn't match.

The first pattern matches as little as it can from the start, and the last
pattern matches as little as it can from the end, so the middle pattern gets
the rest. Each pattern can be empty, otherwise it must be a valid pattern on
its own (a ``2201B`` error).

**Examples**

.. code-block:: sql

  VALUES SUBSTRING('hello' FROM 2);
  -- COL1: ello

  VALUES SUBSTRING('hello' FROM 20);
  -- COL1:

  VALUES SUBSTRING('hello world' FROM 3 FOR 5);
  -- COL1: llo w

  VALUES SUBSTRING('hello' FROM 0 FOR 3);
  -- COL1: he

  VALUES SUBSTRING('Жabڣc' FROM 4 USING OCTETS);
  -- COL1: bڣc

  VALUES SUBSTRING('hello' FROM 2 FOR -1);
  -- error 22011: substring error

  VALUES SUBSTRING('foobar' SIMILAR '%#"o_b#"%' ESCAPE '#');
  -- COL1: oob

  VALUES SUBSTRING('aaabbb' SIMILAR 'a+#"%#"b*' ESCAPE '#');
  -- COL1: aabbb

  VALUES SUBSTRING('foobar' SIMILAR '#"o_b#"%' ESCAPE '#');
  -- COL1: NULL

  VALUES SUBSTRING('foobar' SIMILAR '%o_b%' ESCAPE '#');
  -- error 2200C: invalid use of escape character

**Compatibility**

- **SQL standard:** Core SQL (E021-06). ``USING`` is part of T061 (UCS
  support), and ``SIMILAR`` is T581 (Regular expression substring function).
- **Other databases:** none of them have ``USING``.

  - PostgreSQL: ``SUBSTRING(string FROM start FOR length)``,
    ``SUBSTRING(string, start, length)`` or ``SUBSTR``.
  - MySQL: ``SUBSTRING(string FROM start FOR length)``,
    ``SUBSTRING(string, start, length)`` or ``SUBSTR``.
  - SQLite: ``SUBSTR(string, start, length)`` or ``SUBSTRING``.
  - SQL Server: ``SUBSTRING(string, start, length)``, the length is required.
  - Oracle: ``SUBSTR(string, start, length)``.

  Only PostgreSQL has ``SIMILAR`` (and also the older
  ``SUBSTRING(string FROM pattern FOR escape)``). The others use a different
  regular expression function, such as ``REGEXP_SUBSTR``.

  A negative ``START`` counts from the end of the string in MySQL, SQLite and
  Oracle, so ``SUBSTR('hello', -3)`` is ``'llo'`` there.

TRIM
^^^^

.. code-block:: text

  TRIM(
    [ [ { LEADING | TRAILING | BOTH } ] [ CHARACTER ] FROM ]
    STRING
  )

.. code-block:: sql

   TRIM(CHARACTER VARYING(n)) CHARACTER VARYING(n)
   TRIM(BINARY VARYING(n)) BINARY VARYING(n)
   TRIM(BINARY LARGE OBJECT(n)) BINARY LARGE OBJECT(n)

Removes ``CHARACTER`` from the start (``LEADING``), the end (``TRAILING``) or
both ends (``BOTH``) of ``STRING``, as many times as it's repeated. The result
is a ``CHARACTER VARYING`` with the maximum length of ``STRING``.

If ``LEADING``, ``TRAILING`` or ``BOTH`` is not provided, ``BOTH`` is used.

If ``CHARACTER`` is not provided, a space (``' '``) is used. Only that
character is removed, not other white space such as tabs or new lines.
``CHARACTER`` must be exactly one character, otherwise it's a ``22027`` error
(trim error).

``STRING`` can also be a binary string (see :doc:`binary`), and then
``CHARACTER`` is a binary string of one octet, which is ``X'00'`` if it's not
provided. The result is a ``BINARY VARYING`` with the maximum length of
``STRING``, or a ``BINARY LARGE OBJECT`` for one.

``TRIM(FROM STRING)``, without ``LEADING``, ``TRAILING``, ``BOTH`` or
``CHARACTER``, is a vsql extension flagged by ``V404-01`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES TRIM('  hello world ');
  -- COL1: hello world

  VALUES TRIM('a' FROM 'aaababccaa');
  -- COL1: babcc

  VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
  -- COL1: babccaa

  VALUES TRIM(TRAILING 'a' FROM 'aaababccaa');
  -- COL1: aaababcc

  VALUES TRIM('ab' FROM 'abxab');
  -- error 22027: trim error

**Compatibility**

- **SQL standard:** Core SQL (E021-09).
- **Other databases:**

  - PostgreSQL: ``TRIM``, ``BTRIM``, ``LTRIM`` and ``RTRIM``. The characters
    can be more than one, any of them is removed.
  - MySQL: ``TRIM``. The characters can be more than one, and they're removed
    as a whole string. ``LTRIM`` and ``RTRIM`` only remove spaces.
  - SQLite: ``TRIM(string, characters)``, ``LTRIM`` and ``RTRIM``, any of the
    characters is removed.
  - SQL Server: ``TRIM(characters FROM string)``, ``LTRIM`` and ``RTRIM``.
  - Oracle: ``TRIM``, which only allows one character like the standard, and
    ``LTRIM`` and ``RTRIM`` with any number of characters.

UNICODE
^^^^^^^

.. code-block:: sql

   UNICODE(string CHARACTER VARYING) INTEGER

The Unicode code point of the first character of the string. An empty string is
0, and the padding of a ``CHARACTER(n)`` counts, so
``UNICODE(CAST('' AS CHARACTER(3)))`` is 32 (a space). It's the opposite of
``CHR``.

``UNICODE`` is a vsql extension flagged by ``V404-06`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES UNICODE('A');
  -- COL1: 65

  VALUES UNICODE('é');
  -- COL1: 233

  VALUES UNICODE('');
  -- COL1: 0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``ASCII``.
  - MySQL: ``ORD`` (``ASCII`` is only the first byte).
  - SQLite: ``UNICODE``.
  - SQL Server: ``UNICODE``.
  - Oracle: ``ASCII`` (of the first byte in the database character set).

UPPER
^^^^^

.. code-block:: sql

   UPPER(CHARACTER VARYING) CHARACTER VARYING
   UPPER(CHARACTER LARGE OBJECT) CHARACTER LARGE OBJECT

Returns the input string converted to upper-case. The result has the same type
as the input, such as ``CHARACTER(5)`` for ``UPPER('Hello')``.

The full Unicode case mappings are used, so a character may become several
characters, such as ``ß`` to ``SS``. A result that's longer than the maximum
length of the type is truncated, with a warning (``01004``) if any of the
removed characters aren't spaces.

**Examples**

.. code-block:: sql

  VALUES UPPER('Hello');
  -- COL1: HELLO

  VALUES UPPER(CAST('straße' AS VARCHAR(10)));
  -- COL1: STRASSE

  VALUES UPPER('straße');
  -- warning 01004: string data, right truncation
  -- COL1: STRASS

**Compatibility**

- **SQL standard:** Core SQL (E021-08).
- **Other databases:** ``UPPER`` in all of them, and ``UCASE`` in MySQL. SQLite
  only converts ASCII letters (unless it's built with ICU). The others convert
  ``ß`` to ``SS`` only in some collations or versions.
