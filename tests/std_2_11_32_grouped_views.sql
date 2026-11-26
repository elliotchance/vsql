-- # A grouped view has a GROUP BY or HAVING, or a set function without a GROUP
-- # BY. It can be read like any other table (F131).
/* setup */
CREATE TABLE sales (region VARCHAR(10), amount INTEGER);
INSERT INTO sales (region, amount) VALUES ('n', 10), ('n', 20), ('s', 5), ('e', 7), ('e', 8), ('e', 1);
CREATE TABLE regions (region VARCHAR(10), name VARCHAR(20));
INSERT INTO regions (region, name) VALUES ('n', 'North'), ('s', 'South'), ('e', 'East');
CREATE VIEW totals (region, total, n) AS SELECT region, SUM(amount), COUNT(*) FROM sales GROUP BY region;
CREATE VIEW big AS SELECT region FROM sales GROUP BY region HAVING SUM(amount) > 10;
CREATE VIEW overall AS SELECT SUM(amount) AS total FROM sales;

-- # A query that reads a grouped view can have a WHERE, GROUP BY and HAVING
-- # (F131-01).
SELECT region, total FROM totals WHERE total > 5 ORDER BY region;
SELECT n, COUNT(*) AS c FROM totals GROUP BY n HAVING COUNT(*) > 0 ORDER BY n;
SELECT * FROM overall;
-- REGION: e TOTAL: 16
-- REGION: n TOTAL: 30
-- N: 1 C: 1
-- N: 2 C: 1
-- N: 3 C: 1
-- TOTAL: 51

-- # It can be read with other tables (F131-02).
SELECT name, total FROM totals JOIN regions ON totals.region = regions.region ORDER BY name;
SELECT name, total FROM totals, regions WHERE totals.region = regions.region AND n > 1 ORDER BY name;
SELECT t1.region, t2.region FROM totals t1, totals t2 WHERE t1.total < t2.total ORDER BY t1.region, t2.region;
SELECT big.region, total FROM big, totals WHERE big.region = totals.region ORDER BY big.region;
-- NAME: East TOTAL: 16
-- NAME: North TOTAL: 30
-- NAME: South TOTAL: 5
-- NAME: East TOTAL: 16
-- NAME: North TOTAL: 30
-- REGION: e REGION: n
-- REGION: s REGION: e
-- REGION: s REGION: n
-- REGION: e TOTAL: 16
-- REGION: n TOTAL: 30

-- # The select list can have set functions (F131-03).
SELECT SUM(total), MAX(n), MIN(region) FROM totals;
SELECT COUNT(*) FROM big;
-- COL1: 51 COL2: 3 COL3: e
-- COL1: 2

-- # A subquery in a comparison can read a grouped view, or have a GROUP BY and
-- # HAVING (F131-04).
SELECT region, amount FROM sales WHERE amount > (SELECT AVG(total) FROM totals);
SELECT region FROM totals WHERE total = (SELECT MAX(total) FROM totals);
SELECT name FROM regions WHERE region IN (SELECT region FROM big) ORDER BY name;
SELECT name FROM regions r WHERE 15 < (SELECT SUM(amount) FROM sales s WHERE s.region = r.region GROUP BY s.region HAVING COUNT(*) > 1) ORDER BY name;
-- REGION: n AMOUNT: 20
-- REGION: n
-- NAME: East
-- NAME: North
-- NAME: East
-- NAME: North

-- # A single row SELECT (F131-05) is only in an SQL-client module, see
-- # libvsql/module/test.mod.
