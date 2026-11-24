-- # IF(condition, then_value, else_value) is a vsql extension (V401-01). It's
-- # exactly CASE WHEN condition THEN then_value ELSE else_value END.

/* setup */
CREATE TABLE items (name VARCHAR(10), qty INTEGER);
INSERT INTO items (name, qty) VALUES ('apple', 3), ('pear', 0), ('fig', NULL);

/* extensions V401-01 */
VALUES IF(1 < 2, 'yes', 'no');
-- COL1: yes

/* extensions V401-01 */
VALUES IF(1 > 2, 'yes', 'no');
-- COL1: no

-- # NULL (UNKNOWN) chooses the else value, like FALSE.
/* extensions V401-01 */
VALUES ROW(IF(UNKNOWN, 1, 0), IF(CAST(NULL AS BOOLEAN), 1, 0));
-- COL1: 0 COL2: 0

/* extensions V401-01 */
SELECT name, IF(qty > 0, 'in stock', 'sold out') AS status FROM items;
-- NAME: apple STATUS: in stock
-- NAME: pear STATUS: sold out
-- NAME: fig STATUS: sold out

-- # The result type combines the types of both values, as for CASE.
/* types */
/* extensions V401-01 */
VALUES ROW(IF(TRUE, 1, 2.5), IF(FALSE, 'a', 'bcd'), IF(TRUE, NULL, 3), IF(FALSE, 1, NULL));
-- COL1: 1.0 (NUMERIC(11, 1)) COL2: bcd (CHARACTER(3)) COL3: NULL (INTEGER) COL4: NULL (INTEGER)

-- # Only the chosen value is evaluated.
/* extensions V401-01 */
SELECT name, IF(qty = 0, 0, 10 / qty) FROM items;
-- NAME: apple COL2: 3
-- NAME: pear COL2: 0
-- NAME: fig COL2: NULL

-- # The condition can be any search condition.
/* extensions V401-01 */
SELECT name FROM items WHERE IF(qty IS NULL OR qty = 0, FALSE, TRUE);
-- NAME: apple

-- # It can be nested, and used anywhere a value can.
/* extensions V401-01 */
VALUES IF(1 > 2, 'a', IF(2 > 1, 'b', 'c')) || '!';
-- COL1: b!

-- # The condition must be a BOOLEAN.
/* extensions V401-01 */
VALUES IF(1, 'yes', 'no');
-- error 42804: data type mismatch in CASE WHEN: expected BOOLEAN but got INTEGER

-- # The values must have compatible types.
/* extensions V401-01 */
VALUES IF(TRUE, 1, 'no');
-- error 42804: data type mismatch in CASE: expected INTEGER but got CHARACTER(2)

-- # It needs exactly three arguments.
VALUES IF(TRUE, 1);
-- error 42601: syntax error: unexpected ")" at line 1, column 18 near "TRUE, 1)", expecting ","

VALUES IF(TRUE, 1, 2, 3);
-- error 42601: syntax error: unexpected "," at line 1, column 21 near "1, 2, 3", expecting ")"

-- # IF is still a non-reserved word, so it can be the name of a column or a
-- # table, and IF NOT EXISTS works as before.
/* extensions V103-01 V401-01 */
CREATE TABLE IF NOT EXISTS if (if INTEGER);
INSERT INTO if (if) VALUES (5);
SELECT if, IF(if > 1, if, 0) FROM if;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- IF: 5 COL2: 5

/* flags */
/* extensions V401-01 */
SELECT IF(qty > 0, 'yes', 'no') FROM items WHERE name = 'apple';
-- flags: V401-01
-- COL1: yes
