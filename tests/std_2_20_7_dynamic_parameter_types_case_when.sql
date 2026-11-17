-- # A dynamic parameter that's the case operand of a simple CASE has the type
-- # that every <when operand> combines to, including the predicands of a
-- # predicate, such as the 2.5 of "> 2.5" (General Rules, 5.a.xviii.1.C), the
-- # rows of a subquery (D) and the values of an IN list (E).
/* setup */
CREATE TABLE t (x INT, s VARCHAR(10));
INSERT INTO t (x, s) VALUES (1, 'one'), (3, 'three');

/* types */
/* params 2.6 */
VALUES CASE ? WHEN 1 THEN 'a' WHEN > 2.5 THEN 'b' ELSE 'c' END;
-- sql: VALUES CASE 2.6e0 WHEN 1 THEN 'a' WHEN > 2.5 THEN 'b' ELSE 'c' END
-- COL1: b (CHARACTER(1))

/* params 2.6 */
VALUES CASE ? WHEN IN (2.5, 3.5) THEN 'a' ELSE 'b' END;
-- sql: VALUES CASE 2.6e0 WHEN IN (2.5, 3.5) THEN 'a' ELSE 'b' END
-- COL1: b

/* params 2.5 */
VALUES CASE ? WHEN IN (2.5, 3.5) THEN 'a' ELSE 'b' END;
-- sql: VALUES CASE 2.5e0 WHEN IN (2.5, 3.5) THEN 'a' ELSE 'b' END
-- COL1: a

/* types */
/* params 2 */
SELECT x, CASE ? WHEN > x THEN 'gt' WHEN BETWEEN x AND 3 THEN 'between' END FROM t;
-- sql: SELECT x, CASE 2.0e0 WHEN > x THEN 'gt' WHEN BETWEEN x AND 3 THEN 'between' END FROM t
-- X: 1 (INTEGER) COL2: gt      (CHARACTER(7))
-- X: 3 (INTEGER) COL2: NULL (CHARACTER)

/* params 3 */
SELECT x, CASE ? WHEN IN (x, 5) THEN 'in' ELSE 'out' END FROM t;
-- sql: SELECT x, CASE 3.0e0 WHEN IN (x, 5) THEN 'in' ELSE 'out' END FROM t
-- X: 1 COL2: out
-- X: 3 COL2: in

/* params 3 */
VALUES CASE ? WHEN IN (SELECT x FROM t) THEN 'in' ELSE 'out' END;
VALUES CASE ? WHEN = ANY (SELECT x FROM t) THEN 'any' ELSE 'none' END;
-- sql: VALUES CASE 3.0e0 WHEN IN (SELECT x FROM t) THEN 'in' ELSE 'out' END
-- COL1: in
-- sql: VALUES CASE 3.0e0 WHEN = ANY (SELECT x FROM t) THEN 'any' ELSE 'none' END
-- COL1: any

/* types */
/* params 'one' 'one' */
VALUES CASE ? WHEN LIKE 'o__' THEN 'o' END, CASE ? WHEN SIMILAR TO 't(w|h)%' THEN 't' ELSE 'not t' END;
-- sql: VALUES CASE 'one' WHEN LIKE 'o__' THEN 'o' END, CASE 'one' WHEN SIMILAR TO 't(w|h)%' THEN 't' ELSE 'not t' END
-- COL1: o     (CHARACTER(5))
-- COL1: not t (CHARACTER(5))

/* params 2 */
VALUES CASE ? WHEN IS DISTINCT FROM 2.5 THEN 'distinct' END;
-- sql: VALUES CASE 2.0e0 WHEN IS DISTINCT FROM 2.5 THEN 'distinct' END
-- COL1: distinct

/* params '2020-01-10' '2020-02-10' */
VALUES CASE (?, ?) WHEN OVERLAPS (DATE '2020-02-01', DATE '2020-03-01') THEN 'overlaps' END;
-- sql: VALUES CASE ('2020-01-10', '2020-02-10') WHEN OVERLAPS (DATE '2020-02-01', DATE '2020-03-01') THEN 'overlaps' END
-- COL1: overlaps

-- # IS NULL doesn't have a type, so it doesn't help.
/* params 2 */
VALUES CASE ? WHEN IS NULL THEN 'null' WHEN 2 THEN 'two' END;
VALUES CASE ? WHEN IS NULL THEN 'null' END;
-- sql: VALUES CASE 2.0e0 WHEN IS NULL THEN 'null' WHEN 2 THEN 'two' END
-- COL1: two
-- sql: VALUES CASE 2.0e0 WHEN IS NULL THEN 'null' END
-- error 42601: syntax error: the data type of ?1 cannot be determined
