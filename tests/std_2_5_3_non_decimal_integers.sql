-- # A hexadecimal (0X), octal (0O) or binary (0B) integer is the same as the
-- # decimal integer of its value (Syntax Rules, 23 to 25 and General Rules, 4
-- # to 6), and needs T661 (Conformance Rules, 12). The radix indicator can be
-- # in either case (Syntax Rules, 26).
/* types */
/* flags */
VALUES ROW(0x1F, 0XFF, 0o17, 0O777, 0b101, 0B1111);
-- flags: F641, F661, T051, T661
-- COL1: 31 (SMALLINT) COL2: 255 (SMALLINT) COL3: 15 (SMALLINT) COL4: 511 (SMALLINT) COL5: 5 (SMALLINT) COL6: 15 (SMALLINT)

/* types */
VALUES ROW(0xabcdef, 0x7FFFFFFFFFFFFFFF, 0x10000000000000000);
-- COL1: 11259375 (INTEGER) COL2: 9223372036854775807 (BIGINT) COL3: 18446744073709551616 (NUMERIC(20))

-- # An underscore can be before each digit, including the first one, and needs
-- # T662 (Syntax Rules, 22 to 25 and Conformance Rules, 13).
/* flags */
VALUES ROW(1_000, 1_000_000.000_1, 0x_FF_FF, 0o_7_7, 0b_1010_1010, 1e1_0);
-- flags: F641, F661, T051, T661, T662
-- COL1: 1000 COL2: 1000000.0001 COL3: 65535 COL4: 63 COL5: 170 COL6: 1e+10

/* flags */
VALUES 1_000;
-- flags: F641, F661, T662
-- COL1: 1000

-- # An underscore can't be at the end or next to another one.
VALUES 0x1_;
-- error 42601: syntax error: invalid hexadecimal integer: 0x1_

-- # A digit or letter that isn't of the radix is an error, but a radix indicator
-- # without a digit after it is 0 followed by a name.
VALUES 0b102;
-- error 42601: syntax error: invalid binary integer: 0b102

VALUES 0xFG;
-- error 42601: syntax error: invalid hexadecimal integer: 0xFG

SELECT 0x FROM (VALUES 1) AS t (y);
-- X: 0

-- # It's an integer, so it can't have a period or be a mantissa (Syntax Rules,
-- # 32).
VALUES 0x1.5;
-- error 42601: syntax error: a non-decimal integer cannot have a period or exponent: 0x1.

VALUES 0b1e2;
-- error 42601: syntax error: a non-decimal integer cannot have a period or exponent: 0b1e

-- # It's an <unsigned integer> anywhere one can be used.
/* types */
VALUES CAST('ab' AS VARCHAR(0x2));
-- COL1: ab (CHARACTER VARYING(2))
