-- # x::type is a vsql extension (V303-01), the PostgreSQL shorthand for
-- # CAST(x AS type).
/* extensions V303-01 */
/* types */
VALUES ROW('12'::INT, 1.5::VARCHAR(10), NULL::BIGINT, CAST('3' AS SMALLINT));
-- COL1: 12 (INTEGER) COL2: 1.5 (CHARACTER VARYING(10)) COL3: NULL (BIGINT) COL4: 3 (SMALLINT)

-- # It's flagged the same as the CAST, with V303-01.
/* extensions V303-01 */
/* flags */
VALUES '12'::INT;
-- flags: F641, F661, V303-01
-- COL1: 12

/* flags */
VALUES CAST('12' AS INT);
-- flags: F641, F661
-- COL1: 12

-- # It applies to the primary before it, so a sign is outside of the cast, and
-- # it can be repeated. Spaces are allowed around it.
/* extensions V303-01 */
/* types */
VALUES ROW(-'1'::INT, '7.9'::NUMERIC(3, 1)::INT :: BIGINT, ('2' || '3')::INT * 2);
-- COL1: -1 (INTEGER) COL2: 7 (BIGINT) COL3: 46 (INTEGER)

/* setup */
CREATE TABLE t (x VARCHAR(10));
INSERT INTO t (x) VALUES ('5');

/* extensions V303-01 */
SELECT x::INT + 1 AS y, t.x::INT AS z, COUNT(*)::SMALLINT AS n FROM t GROUP BY x;
-- Y: 6 Z: 5 N: 1

/* extensions V303-01 */
VALUES 'a'::INT;
-- error 22018: invalid character value for cast

VALUES 1::NOPE;
-- error 42601: syntax error: unexpected identifier at line 1, column 11 near "VALUES 1::NOPE"

VALUES 1::;
-- error 42601: syntax error: unexpected $end at line 1, column 11 near "VALUES 1::"

-- # A single colon is still a colon.
VALUES 1:INT;
-- error 42601: syntax error: unexpected ":" at line 1, column 9 near "VALUES 1:INT"
