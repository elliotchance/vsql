-- # Spaces in a binary string literal are ignored, even between the two
-- # hexits of an octet (Part 2, 5.3, Syntax Rules, 4), which is T024
-- # (Conformance Rules, 10).
/* types */
VALUES X'0A 1B';
-- COL1: 0A1B (BINARY(2))

/* types */
VALUES X' 0 A1B  ';
-- COL1: 0A1B (BINARY(2))

/* types */
VALUES X'   ';
-- COL1:  (BINARY(0))

/* flags */
VALUES X'CA FE';
-- flags: F641, F661, T021, T024
-- COL1: CAFE

-- # Only spaces are ignored, the number of hexits must still be even, and a
-- # tab isn't a space.
VALUES X'0A 1';
-- error 42601: syntax error: X'0A 1' is not a valid binary string literal

VALUES X'0A	1B';
-- error 42601: syntax error: X'0A	1B' is not a valid binary string literal

-- # A binary string literal can continue in another part after a separator that
-- # has a newline (5.3, Syntax Rules, 5 and 7), which is T023 (Conformance
-- # Rules, 9). Each part can have spaces.
/* types */
VALUES X'01'
  '02'
  '03';
-- COL1: 010203 (BINARY(3))

/* flags */
VALUES X'01'
  '0 2';
-- flags: F641, F661, T021, T023, T024
-- COL1: 0102

-- # An octet can't be split between the parts, since each part on its own has
-- # an even number of hexits.
VALUES X'0'
  '1';
-- error 42601: syntax error: X'0' is not a valid binary string literal
