SELECT * FROM (VALUES 1);
-- COL1: 1

EXPLAIN SELECT * FROM (VALUES 1);
-- EXPLAIN: $1:
-- EXPLAIN:   VALUES (COL1 NUMERIC) = ROW(1)
-- EXPLAIN: TABLE $1 (COL1 NUMERIC)
-- EXPLAIN: EXPR ($1.COL1 NUMERIC)

EXPLAIN SELECT * FROM (VALUES 1.23);
-- EXPLAIN: $1:
-- EXPLAIN:   VALUES (COL1 NUMERIC) = ROW(1.23)
-- EXPLAIN: TABLE $1 (COL1 NUMERIC)
-- EXPLAIN: EXPR ($1.COL1 NUMERIC)

SELECT * FROM (VALUES 1.23);
-- COL1: 1.23

SELECT * FROM (VALUES 1, 'foo', TRUE);
-- COL1: 1
-- COL1: foo
-- COL1: TRUE

EXPLAIN SELECT * FROM (VALUES ROW(1, 'foo', TRUE));
-- EXPLAIN: $1:
-- EXPLAIN:   VALUES (COL1 NUMERIC, COL2 CHARACTER VARYING(3), COL3 BOOLEAN) = ROW(1, 'foo', TRUE)
-- EXPLAIN: TABLE $1 (COL1 NUMERIC, COL2 CHARACTER VARYING(3), COL3 BOOLEAN)
-- EXPLAIN: EXPR ($1.COL1 NUMERIC, $1.COL2 CHARACTER VARYING(3), $1.COL3 BOOLEAN)

EXPLAIN SELECT * FROM (VALUES 1, 'foo', TRUE) AS t1 (abc, col2, "f");
-- EXPLAIN: T1:
-- EXPLAIN:   VALUES (ABC NUMERIC, COL2 NUMERIC, "f" NUMERIC) = ROW(1), ROW('foo'), ROW(TRUE)
-- EXPLAIN: TABLE T1 (ABC NUMERIC, COL2 NUMERIC, "f" NUMERIC)
-- EXPLAIN: EXPR (T1.ABC NUMERIC, T1.COL2 NUMERIC, T1."f" NUMERIC)

EXPLAIN SELECT * FROM (VALUES ROW(1, 'foo', TRUE)) AS t1 (abc, col2, "f");
-- EXPLAIN: T1:
-- EXPLAIN:   VALUES (ABC NUMERIC, COL2 CHARACTER VARYING(3), "f" BOOLEAN) = ROW(1, 'foo', TRUE)
-- EXPLAIN: TABLE T1 (ABC NUMERIC, COL2 CHARACTER VARYING(3), "f" BOOLEAN)
-- EXPLAIN: EXPR (T1.ABC NUMERIC, T1.COL2 CHARACTER VARYING(3), T1."f" BOOLEAN)

SELECT * FROM (VALUES 1, 'foo', TRUE) AS t1 (abc, col2, "f");
-- error 42601: syntax error: unknown column: T1.COL2

SELECT * FROM (VALUES ROW(1, 'foo', TRUE)) AS t1 (abc, col2, "f");
-- ABC: 1 COL2: foo f: TRUE

/* types */
VALUES 'cool';
-- COL1: cool (CHARACTER(4))

/* types */
VALUES 'cool', 12.3;
-- COL1: cool (CHARACTER(4))
-- COL1: 12.3 (NUMERIC)

/* types */
VALUES ROW('cool', 12.3);
-- COL1: cool (CHARACTER(4)) COL2: 12.3 (NUMERIC)

/* types */
VALUES '12.3';
-- COL1: 12.3 (CHARACTER(4))

/* types */
VALUES '2022-06-30 21:47:32';
-- COL1: 2022-06-30 21:47:32 (CHARACTER(19))

EXPLAIN VALUES 'hello';
-- EXPLAIN: VALUES (COL1 CHARACTER(5)) = ROW('hello')

EXPLAIN VALUES 'hello', 1.22;
-- EXPLAIN: VALUES (COL1 CHARACTER(5)) = ROW('hello'), ROW(1.22)

EXPLAIN VALUES ROW('hello', 1.22);
-- EXPLAIN: VALUES (COL1 CHARACTER(5), COL2 NUMERIC) = ROW('hello', 1.22)

SELECT * FROM (VALUES ROW(123), ROW(456));
-- COL1: 123
-- COL1: 456

EXPLAIN SELECT * FROM (VALUES ROW(123), ROW(456));
-- EXPLAIN: $1:
-- EXPLAIN:   VALUES (COL1 NUMERIC) = ROW(123), ROW(456)
-- EXPLAIN: TABLE $1 (COL1 NUMERIC)
-- EXPLAIN: EXPR ($1.COL1 NUMERIC)

SELECT * FROM (VALUES ROW(123, 'hi'), ROW(456, 'there'));
-- COL1: 123 COL2: hi
-- COL1: 456 COL2: there

EXPLAIN SELECT * FROM (VALUES ROW(123, 'hi'), ROW(456, 'there'));
-- EXPLAIN: $1:
-- EXPLAIN:   VALUES (COL1 NUMERIC, COL2 CHARACTER VARYING(2)) = ROW(123, 'hi'), ROW(456, 'there')
-- EXPLAIN: TABLE $1 (COL1 NUMERIC, COL2 CHARACTER VARYING(2))
-- EXPLAIN: EXPR ($1.COL1 NUMERIC, $1.COL2 CHARACTER VARYING(2))

SELECT * FROM (VALUES ROW(123, 'hi'), ROW(456, 'there')) AS foo (bar, baz);
-- BAR: 123 BAZ: hi
-- BAR: 456 BAZ: there

EXPLAIN SELECT *
FROM (VALUES ROW(123, 'hi'), ROW(456, 'there')) AS foo (bar, baz);
-- EXPLAIN: FOO:
-- EXPLAIN:   VALUES (BAR NUMERIC, BAZ CHARACTER VARYING(2)) = ROW(123, 'hi'), ROW(456, 'there')
-- EXPLAIN: TABLE FOO (BAR NUMERIC, BAZ CHARACTER VARYING(2))
-- EXPLAIN: EXPR (FOO.BAR NUMERIC, FOO.BAZ CHARACTER VARYING(2))

SELECT * FROM (VALUES 1, 2) AS t1 (foo);
-- FOO: 1
-- FOO: 2

SELECT * FROM (VALUES 1, 2) AS t1 (foo, bar, baz);
-- error 42601: syntax error: unknown column: T1.BAR

SELECT * FROM (VALUES ROW(1, 2), ROW(3, 4)) AS t1 (foo, bar);
-- FOO: 1 BAR: 2
-- FOO: 3 BAR: 4

SELECT * FROM (VALUES ROW(1, 2), ROW(3, 4)) AS t1 (foo);
-- error 42601: syntax error: ROW provides the wrong number of columns for the correlation

SELECT * FROM (VALUES ROW(1), ROW(3, 4)) AS t1 (foo, bar);
-- error 42601: syntax error: ROW provides the wrong number of columns for the correlation

EXPLAIN SELECT * FROM (VALUES ROW(1, 2), ROW(3, 4), ROW(5, 6)) AS t1 (foo, bar)
FETCH FIRST 2 ROWS ONLY;
-- EXPLAIN: T1:
-- EXPLAIN:   VALUES (FOO NUMERIC, BAR NUMERIC) = ROW(1, 2), ROW(3, 4), ROW(5, 6)
-- EXPLAIN: TABLE T1 (FOO NUMERIC, BAR NUMERIC)
-- EXPLAIN: FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (T1.FOO NUMERIC, T1.BAR NUMERIC)

SELECT * FROM (VALUES ROW(1, 2), ROW(3, 4), ROW(5, 6)) AS t1 (foo, bar)
FETCH FIRST 2 ROWS ONLY;
-- FOO: 1 BAR: 2
-- FOO: 3 BAR: 4

EXPLAIN SELECT * FROM (VALUES ROW(1, 2), ROW(3, 4), ROW(5, 6)) AS t1 (foo, bar)
OFFSET 1 ROW;
-- EXPLAIN: T1:
-- EXPLAIN:   VALUES (FOO NUMERIC, BAR NUMERIC) = ROW(1, 2), ROW(3, 4), ROW(5, 6)
-- EXPLAIN: TABLE T1 (FOO NUMERIC, BAR NUMERIC)
-- EXPLAIN: OFFSET 1 ROWS
-- EXPLAIN: EXPR (T1.FOO NUMERIC, T1.BAR NUMERIC)

SELECT * FROM (VALUES ROW(1, 2), ROW(3, 4), ROW(5, 6)) AS t1 (foo, bar)
OFFSET 1 ROW;
-- FOO: 3 BAR: 4
-- FOO: 5 BAR: 6

SELECT * FROM (VALUES ROW(1, 2), ROW(3, 4), ROW(5, 6)) AS t1 (foo, bar)
OFFSET 10 ROWS;
