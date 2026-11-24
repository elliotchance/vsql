-- # QUOTE and QUOTE_IDENT are vsql extensions (V404-14 and V404-15) that build
-- # SQL text: QUOTE is a literal that results in the same value, and QUOTE_IDENT
-- # is a delimited identifier.

/* setup */
CREATE TABLE t (id INT, s VARCHAR(20), c CHARACTER(5), n NUMERIC(6, 2), d DOUBLE PRECISION, r REAL, b BOOLEAN, dt DATE, x VARBINARY(4));
INSERT INTO t VALUES (1, 'O''Reilly', 'ab', 1.50, 0.1e0, 0.1e0, TRUE, DATE '2026-11-17', X'DEAD'), (2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- # A character string is in single quotes, with each ' doubled. The result is
-- # a CHARACTER VARYING.
/* types */
VALUES ROW(QUOTE('O''Reilly'), QUOTE('it''s ''quoted'''), QUOTE(''), QUOTE('😊'));
-- COL1: 'O''Reilly' (CHARACTER VARYING) COL2: 'it''s ''quoted''' (CHARACTER VARYING) COL3: '' (CHARACTER VARYING) COL4: '😊' (CHARACTER VARYING)

-- # The padding of a CHARACTER is kept.
VALUES QUOTE(CAST('ab' AS CHARACTER(5)));
-- COL1: 'ab   '

-- # Exact numbers keep their scale.
VALUES ROW(QUOTE(42), QUOTE(-7), QUOTE(CAST(5 AS SMALLINT)), QUOTE(12345678901234), QUOTE(1.50), QUOTE(-0.25));
-- COL1: 42 COL2: -7 COL3: 5 COL4: 12345678901234 COL5: 1.50 COL6: -0.25

-- # Approximate numbers are the shortest form that converts back to the same
-- # value, with an exponent so that they stay approximate.
VALUES ROW(QUOTE(1.5e0), QUOTE(0.1e0), QUOTE(CAST(0.1 AS REAL)), QUOTE(1e300), QUOTE(-1.5e-10), QUOTE(100e0));
-- COL1: 1.5e0 COL2: 0.1e0 COL3: 0.1e0 COL4: 1e+300 COL5: -1.5e-10 COL6: 100.0e0

-- # There's no DECFLOAT literal, so it's a CAST.
VALUES QUOTE(CAST(1.50 AS DECFLOAT));
-- COL1: CAST('1.50' AS DECFLOAT(34))

VALUES ROW(QUOTE(TRUE), QUOTE(FALSE));
-- COL1: TRUE COL2: FALSE

-- # Datetimes and intervals.
VALUES ROW(QUOTE(DATE '2026-11-17'), QUOTE(TIME '12:30:00'), QUOTE(TIME '12:30:00+10:00'));
-- COL1: DATE '2026-11-17' COL2: TIME '12:30:00' COL3: TIME '12:30:00+10:00'

VALUES ROW(QUOTE(TIMESTAMP '2026-11-17 12:30:00.123456+10:00'), QUOTE(TIMESTAMP '2026-11-17 12:30:00'));
-- COL1: TIMESTAMP '2026-11-17 12:30:00.123456+10:00' COL2: TIMESTAMP '2026-11-17 12:30:00'

VALUES ROW(QUOTE(INTERVAL '1-2' YEAR TO MONTH), QUOTE(INTERVAL '3 04:05:06' DAY TO SECOND), QUOTE(INTERVAL '-5' HOUR));
-- COL1: INTERVAL '1-02' YEAR(2) TO MONTH COL2: INTERVAL '3 04:05:06.000000' DAY(2) TO SECOND(6) COL3: INTERVAL '-5' HOUR(2)

-- # Binary strings.
VALUES ROW(QUOTE(X'DEADBEEF'), QUOTE(X''), QUOTE(CAST(X'01' AS BINARY(2))));
-- COL1: X'DEADBEEF' COL2: X'' COL3: X'0100'

-- # A large object is quoted as a CHARACTER LARGE OBJECT.
/* types */
VALUES ROW(QUOTE(CAST('a''b' AS CLOB)), QUOTE(CAST(X'0102' AS BLOB)));
-- COL1: 'a''b' (CHARACTER LARGE OBJECT) COL2: X'0102' (CHARACTER LARGE OBJECT)

-- # A NULL of any type is NULL, not a NULL value, so it can be put in a
-- # statement.
/* types */
SELECT QUOTE(s), QUOTE(c), QUOTE(n), QUOTE(d), QUOTE(r), QUOTE(b), QUOTE(dt), QUOTE(x) FROM t WHERE id = 2;
-- COL1: NULL (CHARACTER VARYING) COL2: NULL (CHARACTER VARYING) COL3: NULL (CHARACTER VARYING) COL4: NULL (CHARACTER VARYING) COL5: NULL (CHARACTER VARYING) COL6: NULL (CHARACTER VARYING) COL7: NULL (CHARACTER VARYING) COL8: NULL (CHARACTER VARYING)

VALUES ROW(QUOTE(CAST(NULL AS INTEGER)) IS NULL, QUOTE(CAST(NULL AS CLOB)), QUOTE(CAST(NULL AS INTERVAL DAY)));
-- COL1: FALSE COL2: NULL COL3: NULL

-- # Building an INSERT for each row.
SELECT 'INSERT INTO t VALUES (' || QUOTE(id) || ', ' || QUOTE(s) || ', ' || QUOTE(c) || ', ' || QUOTE(n) || ', ' || QUOTE(d) || ', ' || QUOTE(r) || ', ' || QUOTE(b) || ', ' || QUOTE(dt) || ', ' || QUOTE(x) || ');' FROM t ORDER BY id;
-- COL1: INSERT INTO t VALUES (1, 'O''Reilly', 'ab   ', 1.50, 0.1e0, 0.1e0, TRUE, DATE '2026-11-17', X'DEAD');
-- COL1: INSERT INTO t VALUES (2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- # Those statements give the same rows.
CREATE TABLE t2 (id INT, s VARCHAR(20), c CHARACTER(5), n NUMERIC(6, 2), d DOUBLE PRECISION, r REAL, b BOOLEAN, dt DATE, x VARBINARY(4));
INSERT INTO t2 VALUES (1, 'O''Reilly', 'ab   ', 1.50, 0.1e0, 0.1e0, TRUE, DATE '2026-11-17', X'DEAD');
INSERT INTO t2 VALUES (2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
SELECT COUNT(*) FROM t2 JOIN t ON t2.id = t.id AND t2.s IS NOT DISTINCT FROM t.s AND t2.c IS NOT DISTINCT FROM t.c AND t2.n IS NOT DISTINCT FROM t.n AND t2.d IS NOT DISTINCT FROM t.d AND t2.r IS NOT DISTINCT FROM t.r AND t2.b IS NOT DISTINCT FROM t.b AND t2.dt IS NOT DISTINCT FROM t.dt AND t2.x IS NOT DISTINCT FROM t.x;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 2

-- # The literals result in the same values.
VALUES ROW(CAST(0.1 AS REAL) = CAST(0.1e0 AS REAL), CAST('1.50' AS DECFLOAT(34)) = CAST(1.50 AS DECFLOAT), INTERVAL '1-02' YEAR(2) TO MONTH = INTERVAL '1-2' YEAR TO MONTH, INTERVAL '3 04:05:06.000000' DAY(2) TO SECOND(6) = INTERVAL '3 04:05:06' DAY TO SECOND, TIMESTAMP '2026-11-17 12:30:00.123456+10:00' = TIMESTAMP '2026-11-17 12:30:00.123456+10:00');
-- COL1: TRUE COL2: TRUE COL3: TRUE COL4: TRUE COL5: TRUE

-- # QUOTE_IDENT always puts the name in double quotes, with each " doubled, so
-- # it keeps its case.
/* types */
VALUES ROW(QUOTE_IDENT('Order Details'), QUOTE_IDENT('CustomerID'), QUOTE_IDENT('a"b'), QUOTE_IDENT('select'), QUOTE_IDENT('X'));
-- COL1: "Order Details" (CHARACTER VARYING) COL2: "CustomerID" (CHARACTER VARYING) COL3: "a""b" (CHARACTER VARYING) COL4: "select" (CHARACTER VARYING) COL5: "X" (CHARACTER VARYING)

-- # A qualified name isn't split.
VALUES ROW(QUOTE_IDENT('s.t'), QUOTE_IDENT('s') || '.' || QUOTE_IDENT('t'));
-- COL1: "s.t" COL2: "s"."t"

-- # NULL is NULL, and an empty name isn't an identifier.
VALUES QUOTE_IDENT(CAST(NULL AS VARCHAR(10)));
VALUES QUOTE_IDENT('');
-- COL1: NULL
-- error 22023: invalid parameter value: QUOTE_IDENT: an identifier can't be empty

-- # They're routines of the VSQL schema. QUOTE has one for each type, and it's
-- # called with a NULL.
VALUES ROW(VSQL.QUOTE(1), VSQL.QUOTE_IDENT('a'));
SELECT COUNT(*), MIN(is_null_call), MAX(is_null_call) FROM information_schema.routines WHERE routine_name = 'QUOTE';
-- COL1: 1 COL2: "a"
-- COL1: 20 COL2: NO COL3: NO

-- # The flagger.
/* flags */
SELECT QUOTE(s), QUOTE_IDENT(s) FROM t WHERE id = 1;
-- flags: V404-14, V404-15
-- COL1: 'O''Reilly' COL2: "O'Reilly"
