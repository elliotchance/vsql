-- # An exact literal's scale is the number of digits after the period (Syntax
-- # Rules, 22). A whole number gets the smallest integer type that holds it,
-- # but any period makes it NUMERIC, even with no digits after it.
/* types */
VALUES 1;
-- COL1: 1 (SMALLINT)

/* types */
VALUES 1.23;
-- COL1: 1.23 (NUMERIC(3, 2))

/* types */
VALUES 1.;
-- COL1: 1 (NUMERIC(1))

/* types */
VALUES .23;
-- COL1: 0.23 (NUMERIC(3, 2))

/* types */
VALUES 789;
-- COL1: 789 (SMALLINT)

-- # An exponent makes it an approximate literal, which is DOUBLE PRECISION
-- # (Syntax Rules, 23). There can't be spaces around the E, because a token
-- # can't contain a separator (5.2, Syntax Rules, 5), so E becomes an
-- # identifier.
/* types */
VALUES 1E2;
-- COL1: 100e0 (DOUBLE PRECISION)

VALUES 1 E 2;
-- error 42601: syntax error: unexpected identifier at line 1, column 10 near "VALUES 1 E 2"

VALUES 1E 2;
-- error 42601: syntax error: unexpected identifier at line 1, column 9 near "VALUES 1E 2"

-- # A sign is a monadic operator on the literal (General Rules, 6), and the
-- # exponent can be signed too. The same value is the same double whether it's
-- # written with more digits or a bigger exponent.
/* types */
VALUES -1.2E2;
-- COL1: -120e0 (DOUBLE PRECISION)

/* types */
VALUES +1.2e-2;
-- COL1: 0.012e0 (DOUBLE PRECISION)

/* types */
VALUES 1000000000000e0;
-- COL1: 1e+12 (DOUBLE PRECISION)

/* types */
VALUES 1.e+12;
-- COL1: 1e+12 (DOUBLE PRECISION)

/* types */
VALUES -1000000000000e0;
-- COL1: -1e+12 (DOUBLE PRECISION)

/* types */
VALUES -1.e+12;
-- COL1: -1e+12 (DOUBLE PRECISION)

/* types */
VALUES 0.000000000009e0;
-- COL1: 9e-12 (DOUBLE PRECISION)

/* types */
VALUES 9.e-12;
-- COL1: 9e-12 (DOUBLE PRECISION)

-- # A character literal is a CHARACTER as long as the number of characters in
-- # it, and two quotes in a row are one quote in both the value and the length
-- # (Syntax Rules, 17).
/* types */
VALUES 'hello';
-- COL1: hello (CHARACTER(5))

/* types */
VALUES 'it''s';
-- COL1: it's (CHARACTER(4))

VALUES '''';
-- COL1: '

VALUES ROW('a''''b', '''x''');
-- COL1: a''b COL2: 'x'

VALUES CHARACTER_LENGTH('it''s');
-- COL1: 4

-- # EXPLAIN prints the literal back as SQL, so the quote is doubled again.
/* extensions V001-01 */
EXPLAIN VALUES 'it''s';
-- EXPLAIN: VALUES (COL1 CHARACTER(4)) = ROW('it''s')

-- # A literal must end with a quote. A doubled quote doesn't end it, and each
-- # part of a compound literal needs its own closing quote.
VALUES 'abc;
-- error 42601: syntax error: unterminated string: 'abc

VALUES 'it'';
-- error 42601: syntax error: unterminated string: 'it''

VALUES 'a'
'b;
-- error 42601: syntax error: unterminated string: 'b

-- # Each literal in a row has its own type, and the usual precedence applies to
-- # arithmetic on them.
/* types */
VALUES ROW(123, 456);
-- COL1: 123 (SMALLINT) COL2: 456 (SMALLINT)

/* types */
VALUES ROW(2 + 3 * 5, (2 + 3) * 5);
-- COL1: 17 (SMALLINT) COL2: 25 (SMALLINT)

-- # These are range tests to make sure that literals are given the correct
-- # smallest exact types.

/* types */
VALUES -9223372036854775809;
-- COL1: -9223372036854775809 (NUMERIC(19))

/* types */
VALUES -9223372036854775808;
-- COL1: -9223372036854775808 (BIGINT)

/* types */
VALUES -2147483649;
-- COL1: -2147483649 (BIGINT)

/* types */
VALUES -2147483648;
-- COL1: -2147483648 (INTEGER)

/* types */
VALUES -32769;
-- COL1: -32769 (INTEGER)

/* types */
VALUES -32768;
-- COL1: -32768 (SMALLINT)

/* types */
VALUES 32767;
-- COL1: 32767 (SMALLINT)

/* types */
VALUES 32768;
-- COL1: 32768 (INTEGER)

/* types */
VALUES 2147483647;
-- COL1: 2147483647 (INTEGER)

/* types */
VALUES 2147483648;
-- COL1: 2147483648 (BIGINT)

/* types */
VALUES 9223372036854775807;
-- COL1: 9223372036854775807 (BIGINT)

/* types */
VALUES 9223372036854775808;
-- COL1: 9223372036854775808 (NUMERIC(19))

/* types */
VALUES 999999999999999999;
-- COL1: 999999999999999999 (BIGINT)

/* types */
VALUES 1000000000000000000;
-- COL1: 1000000000000000000 (BIGINT)

/* types */
VALUES -999999999999999999;
-- COL1: -999999999999999999 (BIGINT)

-- # Leading zeros don't count, only the value decides the type.
/* types */
VALUES 0000000000000000000032767;
-- COL1: 32767 (SMALLINT)

/* types */
VALUES 0000000000000000000032768;
-- COL1: 32768 (INTEGER)
