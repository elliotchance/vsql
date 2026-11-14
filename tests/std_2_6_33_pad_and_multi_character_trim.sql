-- # LPAD and RPAD pad a string to a number of characters (T055, Conformance
-- # Rules, 19), with spaces or a padding string that's repeated and cut short
-- # to fit (General Rules, 14). The result is a CHARACTER VARYING of the
-- # maximum length (Syntax Rules, 16.c.i).
/* types */
/* flags */
VALUES ROW(LPAD('abc', 6), RPAD('abc', 6, 'xy'));
-- flags: F641, F661, T051, T055
-- COL1:    abc (CHARACTER VARYING(10485760)) COL2: abcxyx (CHARACTER VARYING(10485760))

VALUES ROW(LPAD('abc', 8, 'xy') || '|', RPAD('é', 3, 'ü') || '|');
-- COL1: xyxyxabc| COL2: éüü|

-- # A string that's longer is cut to the length, from the end for both, and a
-- # length less than 1 is the empty string (General Rules, 14.c and 14.j).
VALUES ROW(LPAD('abcdef', 3), RPAD('abcdef', 3), LPAD('abc', 0) || '|', RPAD('abc', -1) || '|');
-- COL1: abc COL2: abc COL3: | COL4: |

-- # An empty padding string pads nothing.
VALUES LPAD('abc', 5, '') || '|';
-- COL1: abc|

-- # NULL in any argument is NULL (General Rules, 14.a, 14.b and 14.d).
VALUES ROW(LPAD(CAST(NULL AS VARCHAR(1)), 2), RPAD('a', CAST(NULL AS INT)), LPAD('a', 2, CAST(NULL AS VARCHAR(1))));
-- COL1: NULL COL2: NULL COL3: NULL

-- # The length must be an exact number with a scale of 0 (Syntax Rules, 16.b).
VALUES LPAD('a', 2.5);
-- error 42883: function does not exist: LPAD(CHARACTER(1), NUMERIC(2, 1))

VALUES RPAD('a', 2, 3);
-- error 42883: function does not exist: RPAD(CHARACTER(1), SMALLINT, SMALLINT)

VALUES LPAD(1, 2);
-- error 42883: function does not exist: LPAD(SMALLINT, SMALLINT)

-- # LTRIM, RTRIM and BTRIM remove the leading, trailing, or both, characters
-- # that are any of the characters of the trim string, or spaces without one
-- # (T056, Conformance Rules, 20, Syntax Rules, 15 and General Rules, 13). The
-- # result has the (maximum) length of the source.
/* types */
/* flags */
VALUES ROW(LTRIM('  ab  ') || '|', RTRIM('  ab  ') || '|', BTRIM('  ab  ') || '|');
-- flags: F641, F661, T051, T056
-- COL1: ab  | (CHARACTER VARYING(7)) COL2:   ab| (CHARACTER VARYING(7)) COL3: ab| (CHARACTER VARYING(7))

VALUES ROW(LTRIM('xyxabcyx', 'xy'), RTRIM('xyxabcyx', 'xy'), BTRIM('xyxabcyx', 'yx'));
-- COL1: abcyx COL2: xyxabc COL3: abc

VALUES ROW(BTRIM('ééaé', 'é'), BTRIM('xxx', 'x') || '|', LTRIM('', 'x') || '|', RTRIM('abc', '') || '|');
-- COL1: a COL2: | COL3: | COL4: abc|

-- # NULL in either argument is NULL (General Rules, 13.c).
VALUES ROW(LTRIM(CAST(NULL AS VARCHAR(1))), BTRIM('a', CAST(NULL AS VARCHAR(1))));
-- COL1: NULL COL2: NULL

-- # Both must be strings (Syntax Rules, 15.b.i.1).
VALUES BTRIM('a', 1);
-- error 42883: function does not exist: BTRIM(CHARACTER(1), SMALLINT)

VALUES LTRIM(1);
-- error 42883: function does not exist: LTRIM(SMALLINT)
