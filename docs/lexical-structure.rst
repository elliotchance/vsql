Lexical Structure
=================

.. contents::

An SQL statement is a sequence of tokens: keywords (such as ``SELECT``), names
(such as ``my_table``), literals (such as ``123`` or ``'hello'``) and symbols
(such as ``+``, ``<=`` or ``(``). Tokens can be separated by white space and
comments, which are otherwise ignored.

Keywords and names that aren't in double quotes are not case sensitive, so
``select``, ``Select`` and ``SELECT`` are the same keyword. The reserved words
are listed in :doc:`keywords`.

White Space
-----------

A separator is needed between two tokens that would otherwise run together, such
as a keyword followed by a name or a number. It isn't needed next to a symbol, so
``count(*)`` and ``count ( * )`` are the same:

.. code-block:: sql

  VALUES 1+2;
  -- COL1: 3

  VALUES 1   +
    2;
  -- COL1: 3

White space is any Unicode space character (the general categories Zs, Zl and
Zp, such as a no-break space or an ideographic space), a tab, a line feed, a
vertical tab, a form feed, a carriage return or a next line (U+0085). Any other
character that isn't part of a token is an error:

.. code-block:: sql

  VALUES 1 @;
  -- error 42601: syntax error: invalid character: @

A statement that's empty, or only has white space and comments, is a syntax
error.

Comments
--------

A simple comment starts with ``--`` and runs to the end of the line. A bracketed
comment starts with ``/*`` and ends with ``*/``, and can span many lines. Either
one can go anywhere white space can:

.. code-block:: sql

  VALUES 1 -- one
    + 2;
  -- COL1: 3

  VALUES 1 /* one */ + /* two
  */ 2;
  -- COL1: 3

Bracketed comments can be nested, so each ``/*`` needs its own ``*/``. This
makes it easy to comment out some SQL that already has a comment in it:

.. code-block:: sql

  VALUES 1 /* + 2 /* two */ */;
  -- COL1: 1

A bracketed comment that isn't closed is an error:

.. code-block:: sql

  VALUES 4/*2;
  -- error 42601: syntax error: unterminated comment: /*2

After ``--`` the rest of the line is a comment, so a ``/*`` there doesn't start
a bracketed comment:

.. code-block:: sql

  VALUES 1 -- /* not a bracketed comment
    + 2;
  -- COL1: 3

Inside a string literal or a quoted name, ``--`` and ``/*`` are just text.
``1--2`` is ``1`` followed by a comment, not ``1 - -2``.

Literals
--------

A literal is a value written directly in a statement. Each kind of literal is
described in more detail on the page for its type:

.. list-table::
  :header-rows: 1

  * - Literal
    - Examples
    - See

  * - Exact number
    - ``123``, ``-45.67``, ``.5``, ``1_000_000``
    - :ref:`numbers:Literals and Formatting of Exact Numbers`

  * - Non-decimal integer
    - ``0x1F``, ``0o17``, ``0b1010``
    - :ref:`numbers:Literals and Formatting of Exact Numbers`

  * - Approximate number
    - ``1.5e3``, ``2E-4``
    - :ref:`numbers:Literals and Formatting of Approximate Numbers`

  * - Character string
    - ``'hello'``, ``'it''s'``, ``N'hello'``, ``U&'caf\00e9'``
    - :ref:`text:Literals`

  * - Binary string
    - ``X'CAFE'``
    - :ref:`binary:Literals`

  * - Boolean
    - ``TRUE``, ``FALSE``, ``UNKNOWN``
    - :doc:`booleans`

  * - Date and time
    - ``DATE '2010-10-25'``, ``TIME '15:12:47'``,
      ``TIMESTAMP '2010-10-25 15:12:47'``, ``INTERVAL '3' DAY``
    - :doc:`dates-times`

Numbers
^^^^^^^

A number without a ``.`` or an exponent is an integer. It can also be
hexadecimal (``0x``), octal (``0o``) or binary (``0b``), with the prefix in
either case. An underscore can be put before any digit to make a number easier
to read, but not at the end or next to another underscore:

.. code-block:: sql

  VALUES ROW(0x1F, 0o17, 0b101, 1_000_000);
  -- COL1: 31 COL2: 15 COL3: 5 COL4: 1000000

  VALUES 0xFG;
  -- error 42601: syntax error: invalid hexadecimal integer: 0xFG

There can't be any white space inside a number, including around the ``E`` of an
exponent. A sign in front of a number is an operator, so ``- 5`` is the same as
``-5``.

Strings
^^^^^^^

A character string is written in single quotes, and a single quote inside it is
written twice. A string that starts with ``U&`` can contain Unicode escapes, and
``UESCAPE`` chooses another escape character (see :ref:`text:Literals`):

.. code-block:: sql

  VALUES 'it''s';
  -- COL1: it's

  VALUES U&'caf\00e9';
  -- COL1: café

  VALUES U&'caf!00e9' UESCAPE '!';
  -- COL1: café

A binary string is ``X`` followed by hexadecimal digits in single quotes. Spaces
between the digits are ignored:

.. code-block:: sql

  VALUES X'CA FE';
  -- COL1: CAFE

String Continuation
^^^^^^^^^^^^^^^^^^^

Two string literals that are separated by white space or comments that include
a line break are joined into one. This works for character strings (including
``N''`` and ``U&''``, where ``UESCAPE`` goes after the last part) and binary
strings, where each part must have an even number of digits:

.. code-block:: sql

  VALUES 'Hello, '
    'World';
  -- COL1: Hello, World

  VALUES 'Hello, ' -- a comment between the parts
    'World';
  -- COL1: Hello, World

  VALUES X'CA'
    'FE';
  -- COL1: CAFE

Without a line break, the second string is a syntax error:

.. code-block:: sql

  VALUES 'Hello, ' 'World';
  -- error 42601: syntax error: unexpected string at line 1, column 18 near "VALUES 'Hello, ' 'World'"; hint: is a "," missing before 'World'?
