-- # F262 Extended CASE expression and F263 Comma-separated predicates in simple
-- # CASE expression. Each <when operand> of a simple CASE is a predicate with
-- # the case operand on the left, or a value that's compared with =. A WHEN
-- # with a list of them matches if any of them is TRUE (Syntax Rules, 2.i).
/* setup */
CREATE TABLE t (x INT, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'apple'), (5, 'banana'), (10, 'cherry'), (NULL, NULL);
CREATE TABLE u (z INT);
INSERT INTO u (z) VALUES (2), (5);

-- # <comparison predicate part 2>
SELECT x, CASE x WHEN < 5 THEN 'small' WHEN = 5 THEN 'five' WHEN > 5 THEN 'big' ELSE 'none' END FROM t;
-- X: 1 COL2: small
-- X: 5 COL2: five
-- X: 10 COL2: big
-- X: NULL COL2: none

SELECT x, CASE x WHEN <= 5 THEN 'a' WHEN >= 10 THEN 'b' END, CASE x WHEN <> 5 THEN 'not five' END FROM t;
-- X: 1 COL2: a COL3: not five
-- X: 5 COL2: a COL3: NULL
-- X: 10 COL2: b COL3: not five
-- X: NULL COL2: NULL COL3: NULL

-- # <between predicate part 2>
SELECT x, CASE x WHEN BETWEEN 2 AND 9 THEN 'in' WHEN NOT BETWEEN 1 AND 10 THEN 'out' ELSE 'edge' END FROM t;
-- X: 1 COL2: edge
-- X: 5 COL2: in
-- X: 10 COL2: edge
-- X: NULL COL2: edge

VALUES CASE 5 WHEN BETWEEN SYMMETRIC 10 AND 1 THEN 'yes' ELSE 'no' END;
-- COL1: yes

-- # <in predicate part 2>, with a list or a subquery.
SELECT x, CASE x WHEN IN (1, 10) THEN 'a' WHEN NOT IN (5) THEN 'b' ELSE 'c' END FROM t;
-- X: 1 COL2: a
-- X: 5 COL2: c
-- X: 10 COL2: a
-- X: NULL COL2: c

SELECT x, CASE x WHEN IN (SELECT z FROM u) THEN 'in u' ELSE 'not in u' END FROM t;
-- X: 1 COL2: not in u
-- X: 5 COL2: in u
-- X: 10 COL2: not in u
-- X: NULL COL2: not in u

-- # <character like predicate part 2> and <similar predicate part 2>
SELECT y, CASE y WHEN LIKE 'b%' THEN 'b' WHEN NOT LIKE '%e%' THEN 'no e' ELSE 'other' END FROM t;
-- Y: apple COL2: other
-- Y: banana COL2: b
-- Y: cherry COL2: other
-- Y: NULL COL2: other

VALUES CASE 'a_b' WHEN LIKE 'a#_%' ESCAPE '#' THEN 'yes' ELSE 'no' END;
VALUES CASE 'axb' WHEN NOT LIKE 'a#_%' ESCAPE '#' THEN 'yes' ELSE 'no' END;
-- COL1: yes
-- COL1: yes

SELECT y, CASE y WHEN SIMILAR TO '(a|c)%' THEN 'a or c' WHEN NOT SIMILAR TO '%n%' THEN 'no n' END FROM t;
-- Y: apple COL2: a or c
-- Y: banana COL2: NULL
-- Y: cherry COL2: a or c
-- Y: NULL COL2: NULL

VALUES CASE 'a%' WHEN SIMILAR TO 'a#%' ESCAPE '#' THEN 'yes' END;
VALUES CASE 'ab' WHEN NOT SIMILAR TO 'a#%' ESCAPE '#' THEN 'yes' END;
-- COL1: yes
-- COL1: yes

-- # <null predicate part 2>: "WHEN IS NULL" matches a NULL, which = never does.
SELECT x, CASE x WHEN IS NULL THEN 'yes' ELSE 'not' END, CASE x WHEN IS NOT NULL THEN x END FROM t;
-- X: 1 COL2: not COL3: 1
-- X: 5 COL2: not COL3: 5
-- X: 10 COL2: not COL3: 10
-- X: NULL COL2: yes COL3: NULL

-- # <quantified comparison predicate part 2>
SELECT x, CASE x WHEN > ALL (SELECT z FROM u) THEN 'all' WHEN = ANY (SELECT z FROM u) THEN 'any' WHEN < SOME (SELECT z FROM u) THEN 'some' END FROM t;
-- X: 1 COL2: some
-- X: 5 COL2: any
-- X: 10 COL2: all
-- X: NULL COL2: NULL

-- # A <when operand list> matches if any of its <when operand>s is TRUE. The
-- # values and predicates can be mixed.
SELECT x, CASE x WHEN 1, 5 THEN 'a' WHEN > 7, IS NULL THEN 'b' END FROM t;
-- X: 1 COL2: a
-- X: 5 COL2: a
-- X: 10 COL2: b
-- X: NULL COL2: b

VALUES CASE 3 WHEN 1, 2, 3 THEN 'yes' ELSE 'no' END;
VALUES CASE CAST(NULL AS INT) WHEN 1, CAST(NULL AS INT) THEN 'yes' ELSE 'no' END;
-- COL1: yes
-- COL1: no

-- # The <when operand>s are shown without the case operand.
/* extensions V001-01 */
EXPLAIN VALUES CASE 1 WHEN 1, > 2 THEN 'a' WHEN IS NULL THEN 'b' WHEN BETWEEN 3 AND 4 THEN 'c' WHEN IN (5, 6) THEN 'd' END;
-- EXPLAIN: VALUES (COL1 CHARACTER(1)) = ROW(CASE 1 WHEN 1, > 2 THEN 'a' WHEN IS NULL THEN 'b' WHEN BETWEEN 3 AND 4 THEN 'c' WHEN IN (5, 6) THEN 'd' ELSE NULL END)

-- # A CASE can be in a <when operand>, or be the case operand, of another
-- # CASE.
VALUES CASE 1 WHEN = CASE 2 WHEN > 1 THEN 1 END THEN 'a' ELSE 'b' END;
VALUES CASE CASE 2 WHEN > 1 THEN 10 END WHEN > 5 THEN 'a' ELSE 'b' END;
VALUES CASE 1 WHEN > 0 THEN CASE 2 WHEN < 0 THEN 'a' ELSE 'b' END END;
-- COL1: a
-- COL1: a
-- COL1: b

-- # The case operand can be an aggregate.
SELECT CASE COUNT(*) WHEN > 3 THEN 'many' WHEN 0 THEN 'none' ELSE 'few' END FROM t;
SELECT CASE COUNT(x) WHEN > 3 THEN 'many' WHEN 0 THEN 'none' ELSE 'few' END FROM t;
-- COL1: many
-- warning 01003: null value eliminated in set function
-- COL1: few

-- # The case operand and a <when operand> can be rows (F262). They're compared
-- # field by field (8.2, General Rules, 1.b).
VALUES CASE (1, 2) WHEN (1, 3) THEN 'a' WHEN (1, 2) THEN 'b' END;
VALUES CASE ROW(1, 2) WHEN < (1, 3) THEN 'a' END;
VALUES CASE (1, CAST(NULL AS INT)) WHEN IS NULL THEN 'a' WHEN IS NOT NULL THEN 'b' ELSE 'c' END;
VALUES CASE (CAST(NULL AS INT), CAST(NULL AS INT)) WHEN IS NULL THEN 'a' END;
VALUES CASE (5, 5) WHEN IN ((1, 1), (5, 5)) THEN 'a' END;
-- COL1: b
-- COL1: a
-- COL1: c
-- COL1: a
-- COL1: a

-- # The <when operand> must be comparable with the case operand (8.2, Syntax
-- # Rules, 3), including a row of the same degree (8.2, Syntax Rules, 1).
VALUES CASE 1 WHEN > 'a' THEN 1 END;
-- error 42883: cannot compare SMALLINT and CHARACTER(1)

VALUES CASE 1 WHEN 2, 'a' THEN 1 END;
-- error 42883: cannot compare SMALLINT and CHARACTER(1)

VALUES CASE (1, 2) WHEN (1, 2, 3) THEN 1 END;
-- error 42601: syntax error: cannot compare a row of degree 2 with a row of degree 3

VALUES CASE (1, 2) WHEN 1 THEN 1 END;
-- error 42601: syntax error: cannot compare a row of degree 2 with a row of degree 1

-- # A row can't be the case operand of a predicate that needs a single value.
VALUES CASE (1, 2) WHEN LIKE 'a' THEN 1 END;
-- error 42601: syntax error: a row value cannot be used here

-- # Predicates that vsql doesn't have can't be a <when operand>.
VALUES CASE 1 WHEN OVERLAPS (2, 3) THEN 1 END;
-- error 42601: syntax error: unexpected OVERLAPS at line 1, column 20 near "CASE 1 WHEN OVERLAPS ("; hint: OVERLAPS is a reserved word, so it must be quoted to be used as a name, such as "OVERLAPS" (see https://vsql.readthedocs.io/en/latest/keywords.html)

-- # A <when operand> that's a predicate or a row needs F262, and so does a
-- # case operand that's a row (Conformance Rules, 1 and 2). More than one
-- # <when operand> needs F263 (Conformance Rules, 3). SIMILAR needs T141
-- # (Conformance Rules, 4). The Conformance Rules of the predicates also apply,
-- # so a LIKE needs F281 when the case operand isn't a column (Syntax Rules,
-- # 2.k).
/* flags */
SELECT CASE x WHEN 1 THEN 'a' END FROM t WHERE x = 1;
-- flags:
-- COL1: a

/* flags */
SELECT CASE x WHEN > 1 THEN 'a' END FROM t WHERE x = 5;
-- flags: F262
-- COL1: a

/* flags */
SELECT CASE x WHEN 1, 5 THEN 'a' END FROM t WHERE x = 5;
-- flags: F263
-- COL1: a

/* flags */
SELECT CASE y WHEN LIKE 'a%' THEN 'a' WHEN SIMILAR TO 'b%' THEN 'b' END FROM t WHERE x = 5;
-- flags: F262, T141
-- COL1: b

/* flags */
SELECT CASE 'a' WHEN LIKE 'a%' THEN 'a' END FROM t WHERE x = 1;
-- flags: F262, F281
-- COL1: a

/* flags */
SELECT CASE 1 WHEN (1, 2) THEN 'a' ELSE 'b' END FROM t;
-- flags: F262, F641
-- error 42601: syntax error: cannot compare a row of degree 1 with a row of degree 2

/* flags */
SELECT CASE (1, 2) WHEN (1, 2) THEN 'a' END FROM t WHERE x = 1;
-- flags: F262, F641
-- COL1: a
