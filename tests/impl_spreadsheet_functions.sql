-- # The examples of docs/compatibility-spreadsheet.rst, one test per function.
-- # Each example runs with the example tables of the page.

/* setup */
CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);
CREATE TABLE points (x DOUBLE PRECISION, y DOUBLE PRECISION);
INSERT INTO points VALUES (1e0, 2e0), (2e0, 4.1e0), (3e0, 5.9e0), (4e0, 8.2e0);
CREATE TABLE flows (n INTEGER, amount DOUBLE PRECISION);
INSERT INTO flows VALUES (1, -100e0), (2, 30e0), (3, 40e0), (4, 50e0);

-- # EUROCONVERT
-- # =EUROCONVERT(1.2, "DEM", "EUR")
VALUES ROUND(1.2 / 1.95583, 2);
-- COL1: 0.61

-- # BINOMDIST
-- # =BINOMDIST(2, 5, 0.5, FALSE)
VALUES FACTORIAL(5) / (FACTORIAL(2) * FACTORIAL(5 - 2))
  * POWER(0.5e0, 2) * POWER(1 - 0.5e0, 5 - 2);
-- COL1: 0.3125e0

-- # CEILING
-- # =CEILING(17, 5)
VALUES CEIL(17 / 5.0) * 5;
-- COL1: 20

-- # COVAR
-- # =COVAR(B2:B5, A2:A5)
SELECT COVAR_POP(y, x) FROM points;
-- COL1: 2.55e0

-- # EXPONDIST
-- # =EXPONDIST(0.5, 2, TRUE)
VALUES 1 - EXP(-2 * 0.5e0);
-- COL1: 0.632120558829e0

-- # EXPONDIST
-- # =EXPONDIST(0.5, 2, FALSE)
VALUES 2 * EXP(-2 * 0.5e0);
-- COL1: 0.735758882343e0

-- # FLOOR
-- # =FLOOR(17, 5)
VALUES FLOOR(17 / 5.0) * 5;
-- COL1: 15

-- # FORECAST
-- # =FORECAST(5, B2:B5, A2:A5)
SELECT REGR_INTERCEPT(y, x) + REGR_SLOPE(y, x) * 5 FROM points;
-- COL1: 10.15e0

-- # HYPGEOMDIST
-- # =HYPGEOMDIST(1, 2, 3, 6)
VALUES (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
  * (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
  / (FACTORIAL(6) / (FACTORIAL(2) * FACTORIAL(4)) * 1e0);
-- COL1: 0.6e0

-- # LOGNORMDIST
-- # =LOGNORMDIST(2, 0, 1)
VALUES 0.5 * ERFC(-(LN(2e0) - 0) / (1e0 * SQRT(2e0)));
-- COL1: 0.755891404214e0

-- # MODE
/* extensions V405-01 */
-- # =MODE(1, 2, 2, 3)
SELECT MODE() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
-- COL1: 2

-- # NEGBINOMDIST
-- # =NEGBINOMDIST(2, 3, 0.5)
VALUES FACTORIAL(2 + 3 - 1) / (FACTORIAL(3 - 1) * FACTORIAL(2))
  * POWER(0.5e0, 3) * POWER(1 - 0.5e0, 2);
-- COL1: 0.1875e0

-- # NORMDIST
-- # =NORMDIST(1, 0, 1, TRUE)
VALUES 0.5 * ERFC(-(1 - 0) / (1e0 * SQRT(2e0)));
-- COL1: 0.841344746069e0

-- # NORMDIST
-- # =NORMDIST(1, 0, 1, FALSE)
VALUES EXP(-POWER(1 - 0, 2) / (2 * POWER(1e0, 2)))
  / (1e0 * SQRT(2 * PI()));
-- COL1: 0.241970724519e0

-- # NORMSDIST
-- # =NORMSDIST(1)
VALUES 0.5 * ERFC(-1e0 / SQRT(2e0));
-- COL1: 0.841344746069e0

-- # PERCENTILE
-- # =PERCENTILE(B2:B5, 0.25)
SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY y)
FROM points;
-- COL1: 3.575e0

-- # PERCENTRANK
-- # =PERCENTRANK(C2:C5, 3)
SELECT TRUNC(COUNT(*) FILTER (WHERE price < 3)
  / (COUNT(*) - 1e0), 3) FROM products;
-- COL1: 0.666e0

-- # POISSON
-- # =POISSON(2, 3, FALSE)
VALUES EXP(-3e0) * POWER(3e0, 2) / FACTORIAL(2);
-- COL1: 0.224041807655e0

-- # QUARTILE
-- # =QUARTILE(B2:B5, 1)
SELECT PERCENTILE_CONT(1 / 4e0) WITHIN GROUP (ORDER BY y)
FROM points;
-- COL1: 3.575e0

-- # RANK
-- # =RANK(3, C2:C5)
SELECT RANK(3) WITHIN GROUP (ORDER BY price DESC)
FROM products;
-- COL1: 2

-- # RANK
-- # =RANK(3, C2:C5, 1)
SELECT RANK(3) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 3

-- # STDEV
-- # =STDEV(B2:B5)
SELECT STDDEV_SAMP(y) FROM points;
-- COL1: 2.636285265293e0

-- # STDEVP
-- # =STDEVP(B2:B5)
SELECT STDDEV_POP(y) FROM points;
-- COL1: 2.283090011366e0

-- # VAR
-- # =VAR(B2:B5)
SELECT VAR_SAMP(y) FROM points;
-- COL1: 6.95e0

-- # VARP
-- # =VARP(B2:B5)
SELECT VAR_POP(y) FROM points;
-- COL1: 5.2125e0

-- # WEIBULL
-- # =WEIBULL(2, 1.5, 3, TRUE)
VALUES 1 - EXP(-POWER(2 / 3e0, 1.5));
-- COL1: 0.419770204025e0

-- # ZTEST
-- # =ZTEST(B2:B5, 4)
SELECT 0.5 * ERFC((AVG(y) - 4) / (STDDEV_SAMP(y) / SQRT(COUNT(y))) / SQRT(2e0))
FROM points;
-- COL1: 0.212848833428e0

-- # ZTEST
-- # =ZTEST(B2:B5, 4, 2)
SELECT 0.5 * ERFC((AVG(y) - 4) / (2 / SQRT(COUNT(y))) / SQRT(2e0))
FROM points;
-- COL1: 0.146859056376e0

-- # DAVERAGE
-- # =DAVERAGE(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT AVG(price) FROM products WHERE price > 1;
-- COL1: 2.83

-- # DCOUNT
-- # =DCOUNT(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT COUNT(price) FROM products WHERE price > 1;
-- COL1: 3

-- # DCOUNTA
-- # =DCOUNTA(A1:D5, "name", F1:F2), with F1 = "price" and F2 = ">1"
SELECT COUNT(name) FROM products WHERE price > 1;
-- COL1: 3

-- # DGET
-- # =DGET(A1:D5, "price", F1:F2), with F1 = "name" and F2 = "Cherry"
VALUES (SELECT price FROM products WHERE name = 'Cherry');
-- COL1: 4.00

-- # DMAX
-- # =DMAX(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT MAX(price) FROM products WHERE price > 1;
-- COL1: 4.00

-- # DMIN
-- # =DMIN(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT MIN(price) FROM products WHERE price > 1;
-- COL1: 1.50

-- # DPRODUCT
-- # =DPRODUCT(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT PRODUCT(price) FROM products WHERE price > 1;
-- COL1: 18e0

-- # DSTDEV
-- # =DSTDEV(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT STDDEV_SAMP(price) FROM products WHERE price > 1;
-- COL1: 1.258305739212e0

-- # DSTDEVP
-- # =DSTDEVP(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT STDDEV_POP(price) FROM products WHERE price > 1;
-- COL1: 1.027402333828e0

-- # DSUM
-- # =DSUM(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT SUM(price) FROM products WHERE price > 1;
-- COL1: 8.50

-- # DVAR
-- # =DVAR(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT VAR_SAMP(price) FROM products WHERE price > 1;
-- COL1: 1.583333333333e0

-- # DVARP
-- # =DVARP(A1:D5, "price", F1:F2), with F1 = "price" and F2 = ">1"
SELECT VAR_POP(price) FROM products WHERE price > 1;
-- COL1: 1.055555555556e0

-- # DATE
-- # =DATE(2024, 3, 5)
VALUES CAST(CAST(2024 AS VARCHAR(4)) || '-' || SUBSTRING(CAST(100 + 3 AS VARCHAR(3)) FROM 2)
  || '-' || SUBSTRING(CAST(100 + 5 AS VARCHAR(3)) FROM 2) AS DATE);
-- COL1: 2024-03-05

-- # DATEVALUE
-- # =DATEVALUE("2024-03-05")
VALUES CAST('2024-03-05' AS DATE);
-- COL1: 2024-03-05

-- # DAY
-- # =DAY(DATE(2024, 3, 5))
VALUES EXTRACT(DAY FROM DATE '2024-03-05');
-- COL1: 5

-- # HOUR
-- # =HOUR("14:30:15")
VALUES EXTRACT(HOUR FROM TIME '14:30:15');
-- COL1: 14

-- # MINUTE
-- # =MINUTE("14:30:15")
VALUES EXTRACT(MINUTE FROM TIME '14:30:15');
-- COL1: 30

-- # MONTH
-- # =MONTH(DATE(2024, 3, 5))
VALUES EXTRACT(MONTH FROM DATE '2024-03-05');
-- COL1: 3

-- # NOW
/* extensions V402-01 */
-- # =NOW() > DATE(2020, 1, 1)
VALUES NOW() > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # SECOND
-- # =SECOND("14:30:15")
VALUES EXTRACT(SECOND FROM TIME '14:30:15');
-- COL1: 15

-- # TIME
-- # =TIME(14, 30, 5)
VALUES CAST(SUBSTRING(CAST(100 + 14 AS VARCHAR(3)) FROM 2) || ':' || SUBSTRING(CAST(100 + 30 AS VARCHAR(3)) FROM 2)
  || ':' || SUBSTRING(CAST(100 + 5 AS VARCHAR(3)) FROM 2) AS TIME);
-- COL1: 14:30:05

-- # TIMEVALUE
-- # =TIMEVALUE("14:30:15")
VALUES CAST('14:30:15' AS TIME);
-- COL1: 14:30:15

-- # TODAY
-- # =TODAY() > DATE(2020, 1, 1)
VALUES CURRENT_DATE > DATE '2020-01-01';
-- COL1: TRUE

-- # ISOWEEKNUM
/* extensions V402-05 */
-- # =ISOWEEKNUM(DATE(2027, 1, 1))
VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
-- COL1: 53

-- # WEEKDAY
/* extensions V402-02 */
-- # =WEEKDAY(DATE(2026, 11, 15))
VALUES EXTRACT(DOW FROM DATE '2026-11-15') + 1;
-- COL1: 1

-- # WEEKDAY
/* extensions V402-03 */
-- # =WEEKDAY(DATE(2026, 11, 15), 2)
VALUES EXTRACT(ISODOW FROM DATE '2026-11-15');
-- COL1: 7

-- # WEEKDAY
/* extensions V402-03 */
-- # =WEEKDAY(DATE(2026, 11, 15), 3)
VALUES EXTRACT(ISODOW FROM DATE '2026-11-15') - 1;
-- COL1: 6

-- # WEEKNUM
/* extensions V402-02 V402-04 */
-- # =WEEKNUM(DATE(2026, 11, 15))
VALUES (EXTRACT(DOY FROM DATE '2026-11-15') - 1 + MOD(MOD(EXTRACT(DOW FROM DATE '2026-11-15') - EXTRACT(DOY FROM DATE '2026-11-15') + 1, 7) + 7, 7)) / 7 + 1;
-- COL1: 47

-- # WEEKNUM
/* extensions V402-05 */
-- # =WEEKNUM(DATE(2027, 1, 1), 21)
VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
-- COL1: 53

-- # YEAR
-- # =YEAR(DATE(2024, 3, 5))
VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
-- COL1: 2024

-- # BITLSHIFT
-- # =BITLSHIFT(13, 2)
VALUES CAST(13 * POWER(2, 2) AS BIGINT);
-- COL1: 52

-- # BITRSHIFT
-- # =BITRSHIFT(13, 2)
VALUES CAST(FLOOR(13 / POWER(2, 2)) AS BIGINT);
-- COL1: 3

-- # COMPLEX
-- # =COMPLEX(3, 4)
VALUES CAST(3 AS VARCHAR(20)) || '+' || CAST(4 AS VARCHAR(20)) || 'i';
-- COL1: 3+4i

-- # DELTA
-- # =DELTA(5, 4)
VALUES CASE WHEN 5 = 4 THEN 1 ELSE 0 END;
-- COL1: 0

-- # DELTA
-- # =DELTA(0)
VALUES CASE WHEN 0 = 0 THEN 1 ELSE 0 END;
-- COL1: 1

-- # ERF
-- # =ERF(0.5, 1)
VALUES ERF(1) - ERF(0.5);
-- COL1: 0.322200915137e0

-- # ERF
-- # =ERF(1)
VALUES ERF(1);
-- COL1: 0.84270079295e0

-- # ERF.PRECISE
-- # =ERF.PRECISE(1)
VALUES ERF(1);
-- COL1: 0.84270079295e0

-- # ERFC
-- # =ERFC(1)
VALUES ERFC(1);
-- COL1: 0.15729920705e0

-- # ERFC.PRECISE
-- # =ERFC.PRECISE(1)
VALUES ERFC(1);
-- COL1: 0.15729920705e0

-- # GESTEP
-- # =GESTEP(5, 4)
VALUES CASE WHEN 5 >= 4 THEN 1 ELSE 0 END;
-- COL1: 1

-- # GESTEP
-- # =GESTEP(-1)
VALUES CASE WHEN -1 >= 0 THEN 1 ELSE 0 END;
-- COL1: 0

-- # IMABS
-- # =IMABS("3+4i")
VALUES SQRT(3e0 * 3 + 4 * 4);
-- COL1: 5e0

-- # IMARGUMENT
-- # =IMARGUMENT("3+4i")
VALUES ATAN2(4e0, 3e0);
-- COL1: 0.927295218002e0

-- # IMCOS
/* extensions V201-01 */
-- # =IMCOS("1+2i")
SELECT COS(1e0) * COSH(2e0) AS re, -SIN(1e0) * SINH(2e0) AS im;
-- RE: 2.03272300702e0 IM: -3.051897799152e0

-- # IMCOSH
/* extensions V201-01 */
-- # =IMCOSH("1+2i")
SELECT COSH(1e0) * COS(2e0) AS re, SINH(1e0) * SIN(2e0) AS im;
-- RE: -0.642148124716e0 IM: 1.068607421383e0

-- # IMDIV
/* extensions V201-01 */
-- # =IMDIV("3+4i", "1-2i")
SELECT (3e0 * 1 + 4 * -2) / (1 * 1 + -2 * -2) AS re,
       (4e0 * 1 - 3 * -2) / (1 * 1 + -2 * -2) AS im;
-- RE: -1e0 IM: 2e0

-- # IMEXP
/* extensions V201-01 */
-- # =IMEXP("1+2i")
SELECT EXP(1e0) * COS(2e0) AS re, EXP(1e0) * SIN(2e0) AS im;
-- RE: -1.131204383757e0 IM: 2.471726672005e0

-- # IMLN
/* extensions V201-01 */
-- # =IMLN("3+4i")
SELECT LN(SQRT(3e0 * 3 + 4 * 4)) AS re, ATAN2(4e0, 3e0) AS im;
-- RE: 1.609437912434e0 IM: 0.927295218002e0

-- # IMLOG10
/* extensions V201-01 */
-- # =IMLOG10("3+4i")
SELECT LOG10(SQRT(3e0 * 3 + 4 * 4)) AS re, ATAN2(4e0, 3e0) / LN(10e0) AS im;
-- RE: 0.698970004336e0 IM: 0.402719196273e0

-- # IMLOG2
/* extensions V201-01 */
-- # =IMLOG2("3+4i")
SELECT LOG(2e0, SQRT(3e0 * 3 + 4 * 4)) AS re, ATAN2(4e0, 3e0) / LN(2e0) AS im;
-- RE: 2.321928094887e0 IM: 1.337804212451e0

-- # IMPOWER
/* extensions V201-01 */
-- # =IMPOWER("3+4i", 2)
SELECT POWER(3e0 * 3 + 4 * 4, 2 / 2e0) * COS(2 * ATAN2(4e0, 3e0)) AS re,
       POWER(3e0 * 3 + 4 * 4, 2 / 2e0) * SIN(2 * ATAN2(4e0, 3e0)) AS im;
-- RE: -7e0 IM: 24e0

-- # IMPRODUCT
/* extensions V201-01 */
-- # =IMPRODUCT("3+4i", "1-2i")
SELECT 3 * 1 - 4 * -2 AS re, 3 * -2 + 4 * 1 AS im;
-- RE: 11 IM: -2

-- # IMSIN
/* extensions V201-01 */
-- # =IMSIN("1+2i")
SELECT SIN(1e0) * COSH(2e0) AS re, COS(1e0) * SINH(2e0) AS im;
-- RE: 3.165778513216e0 IM: 1.959601041422e0

-- # IMSINH
/* extensions V201-01 */
-- # =IMSINH("1+2i")
SELECT SINH(1e0) * COS(2e0) AS re, COSH(1e0) * SIN(2e0) AS im;
-- RE: -0.489056259041e0 IM: 1.403119250622e0

-- # IMSQRT
/* extensions V201-01 */
-- # =IMSQRT("3+4i")
SELECT POWER(3e0 * 3 + 4 * 4, 0.25e0) * COS(ATAN2(4e0, 3e0) / 2) AS re,
       POWER(3e0 * 3 + 4 * 4, 0.25e0) * SIN(ATAN2(4e0, 3e0) / 2) AS im;
-- RE: 2e0 IM: 1e0

-- # IMSUB
/* extensions V201-01 */
-- # =IMSUB("3+4i", "1-2i")
SELECT 3 - 1 AS re, 4 - -2 AS im;
-- RE: 2 IM: 6

-- # IMSUM
/* extensions V201-01 */
-- # =IMSUM("3+4i", "1-2i")
SELECT 3 + 1 AS re, 4 + -2 AS im;
-- RE: 4 IM: 2

-- # CUMIPMT
-- # =CUMIPMT(0.01, 12, 1000, 1, 6, 0)
SELECT ROUND(pmt * (e - s + 1) - (pmt + pv * r) * (POWER(1 + r, e) - POWER(1 + r, s - 1)) / r, 2)
FROM (SELECT r, pv, s, e, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
      FROM (VALUES (0.01e0, 12, 1000e0, 1, 6)) AS a (r, n, pv, s, e)) AS b;
-- COL1: -48.01e0

-- # CUMPRINC
-- # =CUMPRINC(0.01, 12, 1000, 1, 6, 0)
SELECT ROUND((pmt + pv * r) * (POWER(1 + r, e) - POWER(1 + r, s - 1)) / r, 2)
FROM (SELECT r, pv, s, e, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
      FROM (VALUES (0.01e0, 12, 1000e0, 1, 6)) AS a (r, n, pv, s, e)) AS b;
-- COL1: -485.08e0

-- # DB
-- # =DB(10000, 1000, 5, 2)
SELECT ROUND(10000 * POWER(1 - r, 2 - 1) * r, 2)
FROM (VALUES (ROUND(1 - POWER(1000 / 10000e0, 1 / 5e0), 3))) AS t (r);
-- COL1: 2328.39e0

-- # DDB
-- # =DDB(10000, 1000, 5, 2)
VALUES 10000 * POWER(1 - 2 / 5e0, 2 - 1) * 2 / 5e0;
-- COL1: 2400e0

-- # DDB
-- # =DDB(10000, 1000, 5, 2, 1.5)
VALUES 10000 * POWER(1 - 1.5 / 5e0, 2 - 1) * 1.5 / 5e0;
-- COL1: 2100e0

-- # DOLLARDE
/* extensions V403-01 */
-- # =DOLLARDE(1.02, 16)
VALUES FLOOR(1.02) + MOD(1.02, 1) * POWER(10, CEIL(LOG10(16))) / 16;
-- COL1: 1.125e0

-- # DOLLARFR
/* extensions V403-01 */
-- # =DOLLARFR(1.125, 16)
VALUES FLOOR(1.125) + MOD(1.125, 1) * 16 / POWER(10, CEIL(LOG10(16)));
-- COL1: 1.02e0

-- # EFFECT
-- # =EFFECT(0.0525, 4)
VALUES POWER(1 + 0.0525e0 / 4, 4) - 1;
-- COL1: 0.053542667371e0

-- # FV
-- # =FV(0.005, 12, -100, -1000)
VALUES ROUND(-(-1000 * POWER(1 + 0.005e0, 12) + -100 * (POWER(1 + 0.005e0, 12) - 1) / 0.005), 2);
-- COL1: 2295.23e0

-- # FV
-- # =FV(0.005, 12, -100)
VALUES ROUND(-(-100 * (POWER(1 + 0.005e0, 12) - 1) / 0.005), 2);
-- COL1: 1233.56e0

-- # FVSCHEDULE
-- # =FVSCHEDULE(1000, {0.09, 0.11, 0.1})
SELECT ROUND(1000 * PRODUCT(1 + r), 2)
FROM (VALUES (0.09e0), (0.11e0), (0.1e0)) AS s (r);
-- COL1: 1330.89e0

-- # IPMT
-- # =IPMT(0.01, 3, 12, 1000)
SELECT ROUND(pmt - (pmt + pv * r) * POWER(1 + r, k - 1), 2)
FROM (SELECT r, k, pv, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
      FROM (VALUES (0.01e0, 3, 12, 1000e0)) AS a (r, k, n, pv)) AS b;
-- COL1: -8.42e0

-- # ISPMT
-- # =ISPMT(0.01, 1, 12, 1000)
VALUES ROUND(1000 * 0.01 * (1 / 12e0 - 1), 2);
-- COL1: -9.17e0

-- # MIRR
-- # =MIRR(B2:B5, 0.1, 0.12)
SELECT POWER(SUM(amount * POWER(1.12e0, 4 - n)) FILTER (WHERE amount > 0)
  / -SUM(amount / POWER(1.1e0, n - 1)) FILTER (WHERE amount < 0), 1 / 3e0) - 1
FROM flows;
-- COL1: 0.098156692446e0

-- # NOMINAL
-- # =NOMINAL(0.053543, 4)
VALUES 4 * (POWER(1 + 0.053543e0, 1 / 4e0) - 1);
-- COL1: 0.052500319868e0

-- # NPER
-- # =NPER(0.01, -100, 1000)
VALUES -LN(1 + 1000 * 0.01e0 / -100) / LN(1 + 0.01e0);
-- COL1: 10.588644459423e0

-- # NPV
-- # =NPV(0.1, B2:B5)
SELECT SUM(amount / POWER(1 + 0.1e0, n)) FROM flows;
-- COL1: -1.912437675022e0

-- # PDURATION
-- # =PDURATION(0.025, 2000, 2200)
VALUES LN(2200 / 2000e0) / LN(1 + 0.025e0);
-- COL1: 3.859866162623e0

-- # PMT
-- # =PMT(0.01, 12, 1000)
VALUES ROUND(-1000 * 0.01e0 / (1 - POWER(1 + 0.01e0, -12)), 2);
-- COL1: -88.85e0

-- # PPMT
-- # =PPMT(0.01, 3, 12, 1000)
SELECT ROUND((pmt + pv * r) * POWER(1 + r, k - 1), 2)
FROM (SELECT r, k, pv, -pv * r / (1 - POWER(1 + r, -n)) AS pmt
      FROM (VALUES (0.01e0, 3, 12, 1000e0)) AS a (r, k, n, pv)) AS b;
-- COL1: -80.43e0

-- # PV
-- # =PV(0.005, 12, -100)
VALUES ROUND(-(-100 * (1 - POWER(1 + 0.005e0, -12)) / 0.005), 2);
-- COL1: 1161.89e0

-- # RRI
-- # =RRI(10, 1000, 2000)
VALUES POWER(2000 / 1000e0, 1 / 10e0) - 1;
-- COL1: 0.071773462536e0

-- # SLN
-- # =SLN(10000, 1000, 5)
VALUES (10000 - 1000) / 5.0;
-- COL1: 1800.0

-- # SYD
-- # =SYD(10000, 1000, 5, 2)
VALUES (10000 - 1000.0) * (5 - 2 + 1) * 2 / (5 * (5 + 1));
-- COL1: 2400.0

-- # ARRAYFORMULA
-- # =ARRAYFORMULA(C2:C5 * D2:D5)
SELECT price * COALESCE(qty, 0) AS total FROM products;
-- TOTAL: 15.00
-- TOTAL: 10.00
-- TOTAL: 20.00
-- TOTAL: 0.00

-- # QUERY
-- # =QUERY(A1:D5, "select B where C > 1", 1)
SELECT name FROM products WHERE price > 1;
-- NAME: Apple
-- NAME: Cherry
-- NAME: Date

-- # ISBLANK
-- # =ISBLANK(D5)
SELECT qty IS NULL AS blank FROM products WHERE sku = 'D4';
-- BLANK: TRUE

-- # ISEMAIL
-- # =ISEMAIL("jo.smith@example.com")
VALUES 'jo.smith@example.com' SIMILAR TO '[A-Za-z0-9.]+@[A-Za-z0-9.]+.[A-Za-z]+';
-- COL1: TRUE

-- # ISEVEN
-- # =ISEVEN(10)
VALUES MOD(10, 2) = 0;
-- COL1: TRUE

-- # ISNA
-- # =ISNA(MATCH("Fig", B2:B5, 0))
VALUES (SELECT sku FROM products WHERE name = 'Fig') IS NULL;
-- COL1: TRUE

-- # ISODD
-- # =ISODD(-3)
VALUES MOD(-3, 2) <> 0;
-- COL1: TRUE

-- # ISURL
-- # =ISURL("https://example.com/a")
VALUES 'https://example.com/a' SIMILAR TO 'https?://%';
-- COL1: TRUE

-- # N
-- # =N(TRUE)
VALUES CASE WHEN TRUE THEN 1 ELSE 0 END;
-- COL1: 1

-- # NA
-- # =NA()
VALUES CAST(NULL AS INTEGER);
-- COL1: NULL

-- # AND
-- # =AND(2 > 1, 3 > 2)
VALUES 2 > 1 AND 3 > 2;
-- COL1: TRUE

-- # BYCOL
-- # =BYCOL(A2:B5, LAMBDA(c, MAX(c)))
SELECT MAX(x), MAX(y) FROM points;
-- COL1: 4e0 COL2: 8.2e0

-- # BYROW
-- # =BYROW(C2:D4, LAMBDA(r, PRODUCT(r)))
SELECT price * qty AS total FROM products WHERE qty IS NOT NULL ORDER BY sku;
-- TOTAL: 15.00
-- TOTAL: 10.00
-- TOTAL: 20.00

-- # FALSE
-- # =FALSE()
VALUES FALSE;
-- COL1: FALSE

-- # IF
-- # =IF(2 > 1, "yes", "no")
VALUES CASE WHEN 2 > 1 THEN 'yes' ELSE 'no' END;
-- COL1: yes

-- # IFNA
-- # =IFNA(VLOOKUP("Fig", B2:C5, 2, FALSE), 0)
VALUES COALESCE((SELECT price FROM products WHERE name = 'Fig'), 0);
-- COL1: 0.00

-- # IFS
-- # =IFS(D2 < 10, "low", D2 >= 10, "ok")
SELECT CASE WHEN qty < 10 THEN 'low' WHEN qty >= 10 THEN 'ok' END AS stock
FROM products WHERE qty IS NOT NULL ORDER BY sku;
-- STOCK: ok
-- STOCK: ok
-- STOCK: low

-- # LET
-- # =LET(x, 5, x * x + x)
SELECT x * x + x FROM (VALUES 5) AS t (x);
-- COL1: 30

-- # MAKEARRAY
-- # =MAKEARRAY(2, 3, LAMBDA(r, c, r * c))
SELECT r * 1 AS c1, r * 2 AS c2, r * 3 AS c3 FROM (VALUES 1, 2) AS t (r);
-- C1: 1 C2: 2 C3: 3
-- C1: 2 C2: 4 C3: 6

-- # MAP
-- # =MAP(C2:C5, LAMBDA(p, p * 2))
SELECT price * 2 FROM products ORDER BY sku;
-- COL1: 3.00
-- COL1: 0.50
-- COL1: 8.00
-- COL1: 6.00

-- # NOT
-- # =NOT(2 > 1)
VALUES NOT (2 > 1);
-- COL1: FALSE

-- # OR
-- # =OR(2 > 1, 3 < 2)
VALUES 2 > 1 OR 3 < 2;
-- COL1: TRUE

-- # REDUCE
-- # =REDUCE(0, C2:C5, LAMBDA(a, v, a + v))
SELECT SUM(price) FROM products;
-- COL1: 8.75

-- # SCAN
-- # =SCAN(0, C2:C5, LAMBDA(a, v, a + v))
SELECT (SELECT SUM(price) FROM products AS p WHERE p.sku <= products.sku) AS total
FROM products ORDER BY sku;
-- TOTAL: 1.50
-- TOTAL: 1.75
-- TOTAL: 5.75
-- TOTAL: 8.75

-- # SWITCH
-- # =SWITCH(2, 1, "one", 2, "two", "other")
VALUES CASE 2 WHEN 1 THEN 'one' WHEN 2 THEN 'two' ELSE 'other' END;
-- COL1: two

-- # SWITCH
-- # =SWITCH(3, 1, "one", 2, "two")
VALUES CASE 3 WHEN 1 THEN 'one' WHEN 2 THEN 'two' END;
-- COL1: NULL

-- # TRUE
-- # =TRUE()
VALUES TRUE;
-- COL1: TRUE

-- # XOR
-- # =XOR(TRUE, FALSE)
VALUES TRUE <> FALSE;
-- COL1: TRUE

-- # ARRAY_CONSTRAIN
-- # =ARRAY_CONSTRAIN(A2:D5, 2, 2)
SELECT sku, name FROM products ORDER BY sku FETCH FIRST 2 ROWS ONLY;
-- SKU: A1 NAME: Apple
-- SKU: B2 NAME: Banana

-- # CHOOSE
-- # =CHOOSE(2, "Apple", "Banana", "Cherry")
VALUES CASE 2 WHEN 1 THEN 'Apple' WHEN 2 THEN 'Banana' WHEN 3 THEN 'Cherry' END;
-- COL1: Banana

-- # CHOOSECOLS
-- # =CHOOSECOLS(A2:D5, 2, 3)
SELECT name, price FROM products ORDER BY sku;
-- NAME: Apple PRICE: 1.50
-- NAME: Banana PRICE: 0.25
-- NAME: Cherry PRICE: 4.00
-- NAME: Date PRICE: 3.00

-- # CHOOSEROWS
-- # =CHOOSEROWS(A2:D5, 1, 3)
SELECT * FROM products
WHERE (SELECT COUNT(*) FROM products AS p WHERE p.sku <= products.sku) IN (1, 3);
-- SKU: A1 NAME: Apple PRICE: 1.50 QTY: 10
-- SKU: C3 NAME: Cherry PRICE: 4.00 QTY: 5

-- # DROP
-- # =DROP(A2:D5, 2)
SELECT * FROM products ORDER BY sku OFFSET 2 ROWS;
-- SKU: C3 NAME: Cherry PRICE: 4.00 QTY: 5
-- SKU: D4 NAME: Date PRICE: 3.00 QTY: NULL

-- # EXPAND
-- # =EXPAND(A2:B3, 3, 2, "-")
SELECT sku, name FROM products WHERE sku IN ('A1', 'B2')
UNION ALL VALUES ('-', '-');
-- SKU: A1 NAME: Apple
-- SKU: B2 NAME: Banana
-- SKU: - NAME: -

-- # FILTER
-- # =FILTER(B2:B5, C2:C5 > 1)
SELECT name FROM products WHERE price > 1;
-- NAME: Apple
-- NAME: Cherry
-- NAME: Date

-- # FLATTEN
-- # =FLATTEN(A2:A3, B2:B3)
SELECT sku FROM products WHERE sku IN ('A1', 'B2')
UNION ALL SELECT name FROM products WHERE sku IN ('A1', 'B2');
-- SKU: A1
-- SKU: B2
-- SKU: Apple
-- SKU: Banana

-- # GETPIVOTDATA
-- # =GETPIVOTDATA("qty", F1, "name", "Apple")
SELECT SUM(qty) FROM products WHERE name = 'Apple';
-- COL1: 10

-- # GROUPBY
-- # =GROUPBY(C2:C5 > 1, D2:D5, SUM)
SELECT over_1, SUM(qty) AS qty
FROM (SELECT price > 1 AS over_1, qty FROM products WHERE qty IS NOT NULL) AS t
GROUP BY over_1 ORDER BY over_1;
-- OVER_1: FALSE QTY: 40
-- OVER_1: TRUE QTY: 15

-- # HLOOKUP
-- # =HLOOKUP("price", A1:D5, 3, FALSE)
SELECT price FROM products ORDER BY sku OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
-- PRICE: 0.25

-- # HSTACK
-- # =HSTACK(A2:A5, C2:C5)
SELECT sku, price FROM products ORDER BY sku;
-- SKU: A1 PRICE: 1.50
-- SKU: B2 PRICE: 0.25
-- SKU: C3 PRICE: 4.00
-- SKU: D4 PRICE: 3.00

-- # INDEX
-- # =INDEX(A2:D5, 3, 2)
SELECT name FROM products ORDER BY sku OFFSET 2 ROWS FETCH FIRST 1 ROW ONLY;
-- NAME: Cherry

-- # LOOKUP
-- # =LOOKUP("B9", A2:A5, B2:B5)
SELECT name FROM products WHERE sku <= 'B9'
ORDER BY sku DESC FETCH FIRST 1 ROW ONLY;
-- NAME: Banana

-- # MATCH
-- # =MATCH("Cherry", B2:B5, 0)
SELECT (SELECT COUNT(*) FROM products AS p WHERE p.sku <= products.sku) AS pos
FROM products WHERE name = 'Cherry';
-- POS: 3

-- # ROWS
-- # =ROWS(A2:D5)
SELECT COUNT(*) FROM products;
-- COL1: 4

-- # SORT
-- # =SORT(A2:B5, 2, -1)
SELECT sku, name FROM products ORDER BY name DESC;
-- SKU: D4 NAME: Date
-- SKU: C3 NAME: Cherry
-- SKU: B2 NAME: Banana
-- SKU: A1 NAME: Apple

-- # SORT
-- # =SORT(A2:B5, 2)
SELECT sku, name FROM products ORDER BY name;
-- SKU: A1 NAME: Apple
-- SKU: B2 NAME: Banana
-- SKU: C3 NAME: Cherry
-- SKU: D4 NAME: Date

-- # SORTBY
-- # =SORTBY(B2:B5, C2:C5, -1)
SELECT name FROM products ORDER BY price DESC;
-- NAME: Cherry
-- NAME: Date
-- NAME: Apple
-- NAME: Banana

-- # SORTBY
-- # =SORTBY(B2:B5, C2:C5)
SELECT name FROM products ORDER BY price;
-- NAME: Banana
-- NAME: Apple
-- NAME: Date
-- NAME: Cherry

-- # SORTN
-- # =SORTN(B2:B5, 2, 0, C2:C5, FALSE)
SELECT name FROM products ORDER BY price DESC FETCH FIRST 2 ROWS ONLY;
-- NAME: Cherry
-- NAME: Date

-- # TAKE
-- # =TAKE(B2:B5, 2)
SELECT name FROM products ORDER BY sku FETCH FIRST 2 ROWS ONLY;
-- NAME: Apple
-- NAME: Banana

-- # TOCOL
-- # =TOCOL(A2:B3)
SELECT CASE c.i WHEN 1 THEN sku ELSE name END AS v
FROM products JOIN (VALUES (1), (2)) AS c (i) ON TRUE
WHERE sku IN ('A1', 'B2') ORDER BY sku, c.i;
-- V: A1
-- V: Apple
-- V: B2
-- V: Banana

-- # TOROW
-- # =TOROW(B2:B5)
SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY sku) FROM products;
-- COL1: Apple, Banana, Cherry, Date

-- # UNIQUE
-- # =UNIQUE(C2:C5 > 1)
SELECT DISTINCT price > 1 AS over_1 FROM products;
-- OVER_1: TRUE
-- OVER_1: FALSE

-- # VLOOKUP
-- # =VLOOKUP("C3", A2:D5, 3, FALSE)
VALUES (SELECT price FROM products WHERE sku = 'C3');
-- COL1: 4.00

-- # VSTACK
-- # =VSTACK(A2:B3, A4:B5)
SELECT sku, name FROM products WHERE sku IN ('A1', 'B2')
UNION ALL SELECT sku, name FROM products WHERE sku IN ('C3', 'D4');
-- SKU: A1 NAME: Apple
-- SKU: B2 NAME: Banana
-- SKU: C3 NAME: Cherry
-- SKU: D4 NAME: Date

-- # XLOOKUP
-- # =XLOOKUP("E5", A2:A5, B2:B5, "none")
VALUES COALESCE((SELECT name FROM products WHERE sku = 'E5'), 'none');
-- COL1: none

-- # XLOOKUP
-- # =XLOOKUP("C3", A2:A5, B2:B5)
VALUES (SELECT name FROM products WHERE sku = 'C3');
-- COL1: Cherry

-- # XMATCH
-- # =XMATCH("Cherry", B2:B5)
SELECT (SELECT COUNT(*) FROM products AS p WHERE p.sku <= products.sku) AS pos
FROM products WHERE name = 'Cherry';
-- POS: 3

-- # ABS
-- # =ABS(-4)
VALUES ABS(-4);
-- COL1: 4

-- # ACOS
-- # =ACOS(0.5)
VALUES ACOS(0.5e0);
-- COL1: 1.047197551197e0

-- # ACOSH
-- # =ACOSH(2)
VALUES LN(2e0 + SQRT(2e0 * 2 - 1));
-- COL1: 1.316957896925e0

-- # ACOT
-- # =ACOT(2)
VALUES PI() / 2 - ATAN(2e0);
-- COL1: 0.463647609001e0

-- # ACOTH
-- # =ACOTH(2)
VALUES 0.5e0 * LN((2e0 + 1) / (2e0 - 1));
-- COL1: 0.549306144334e0

-- # AGGREGATE
-- # =AGGREGATE(9, 6, C2:C5)
SELECT SUM(price) FROM products;
-- COL1: 8.75

-- # ASIN
-- # =ASIN(0.5)
VALUES ASIN(0.5e0);
-- COL1: 0.523598775598e0

-- # ASINH
-- # =ASINH(2)
VALUES LN(2e0 + SQRT(2e0 * 2 + 1));
-- COL1: 1.443635475179e0

-- # ATAN
-- # =ATAN(1)
VALUES ATAN(1e0);
-- COL1: 0.785398163397e0

-- # ATAN2
-- # =ATAN2(3, 4)
VALUES ATAN2(4e0, 3e0);
-- COL1: 0.927295218002e0

-- # ATANH
-- # =ATANH(0.5)
VALUES 0.5e0 * LN((1 + 0.5e0) / (1 - 0.5e0));
-- COL1: 0.549306144334e0

-- # CEILING.MATH
-- # =CEILING.MATH(17, 5)
VALUES CEIL(17 / 5.0) * 5;
-- COL1: 20

-- # CEILING.MATH
-- # =CEILING.MATH(4.3)
VALUES CEIL(4.3);
-- COL1: 5

-- # CEILING.PRECISE
-- # =CEILING.PRECISE(-4.3, 2)
VALUES CEIL(-4.3 / ABS(2)) * ABS(2);
-- COL1: -4

-- # COMBIN
-- # =COMBIN(5, 2)
VALUES FACTORIAL(5) / (FACTORIAL(2) * FACTORIAL(5 - 2));
-- COL1: 10

-- # COMBINA
-- # =COMBINA(4, 3)
VALUES FACTORIAL(4 + 3 - 1) / (FACTORIAL(3) * FACTORIAL(4 - 1));
-- COL1: 20

-- # COS
-- # =COS(1)
VALUES COS(1e0);
-- COL1: 0.540302305868e0

-- # COSH
-- # =COSH(1)
VALUES COSH(1e0);
-- COL1: 1.543080634815e0

-- # COT
-- # =COT(1)
VALUES 1 / TAN(1e0);
-- COL1: 0.642092615934e0

-- # COTH
-- # =COTH(1)
VALUES 1 / TANH(1e0);
-- COL1: 1.313035285499e0

-- # CSC
-- # =CSC(1)
VALUES 1 / SIN(1e0);
-- COL1: 1.188395105778e0

-- # CSCH
-- # =CSCH(1)
VALUES 1 / SINH(1e0);
-- COL1: 0.850918128239e0

-- # DEGREES
-- # =DEGREES(PI())
VALUES DEGREES(PI());
-- COL1: 180e0

-- # EVEN
-- # =EVEN(3.2)
VALUES SIGN(3.2) * CEIL(ABS(3.2) / 2) * 2;
-- COL1: 4

-- # EXP
-- # =EXP(1)
VALUES EXP(1e0);
-- COL1: 2.718281828459e0

-- # FACT
-- # =FACT(5)
VALUES FACTORIAL(5);
-- COL1: 120

-- # FLOOR.MATH
-- # =FLOOR.MATH(17, 5)
VALUES FLOOR(17 / 5.0) * 5;
-- COL1: 15

-- # FLOOR.MATH
-- # =FLOOR.MATH(4.7)
VALUES FLOOR(4.7);
-- COL1: 4

-- # FLOOR.PRECISE
-- # =FLOOR.PRECISE(-4.3, 2)
VALUES FLOOR(-4.3 / ABS(2)) * ABS(2);
-- COL1: -6

-- # GCD
-- # =GCD(24, 36, 60)
VALUES GCD(GCD(24, 36), 60);
-- COL1: 12

-- # INT
-- # =INT(-4.3)
VALUES FLOOR(-4.3);
-- COL1: -5

-- # ISO.CEILING
-- # =ISO.CEILING(-4.3, 2)
VALUES CEIL(-4.3 / ABS(2)) * ABS(2);
-- COL1: -4

-- # LCM
-- # =LCM(4, 6, 10)
VALUES LCM(LCM(4, 6), 10);
-- COL1: 60

-- # LN
-- # =LN(10)
VALUES LN(10e0);
-- COL1: 2.302585092994e0

-- # LOG
-- # =LOG(8, 2)
VALUES LOG(2e0, 8e0);
-- COL1: 3e0

-- # LOG
-- # =LOG(100)
VALUES LOG10(100e0);
-- COL1: 2e0

-- # LOG10
-- # =LOG10(1000)
VALUES LOG10(1000e0);
-- COL1: 3e0

-- # MOD
-- # =MOD(-7, 3)
VALUES MOD(MOD(-7, 3) + 3, 3);
-- COL1: 2

-- # MROUND
-- # =MROUND(17, 5)
VALUES ROUND(17 / 5.0) * 5;
-- COL1: 15

-- # MULTINOMIAL
-- # =MULTINOMIAL(2, 3, 4)
VALUES FACTORIAL(2 + 3 + 4)
  / (FACTORIAL(2) * FACTORIAL(3) * FACTORIAL(4));
-- COL1: 1260

-- # ODD
-- # =ODD(3.2)
VALUES SIGN(3.2) * (CEIL((ABS(3.2) + 1) / 2) * 2 - 1);
-- COL1: 5

-- # PERCENTOF
-- # =PERCENTOF(C2:C3, C2:C5)
SELECT SUM(price) FILTER (WHERE sku IN ('A1', 'B2')) / SUM(price)
FROM products;
-- COL1: 0.2000

-- # PI
-- # =PI()
VALUES PI();
-- COL1: 3.14159265359e0

-- # POWER
-- # =POWER(2, 10)
VALUES POWER(2, 10);
-- COL1: 1024e0

-- # PRODUCT
-- # =PRODUCT(D2:D5)
SELECT PRODUCT(qty) FROM products WHERE qty IS NOT NULL;
-- COL1: 2000

-- # QUOTIENT
-- # =QUOTIENT(-7, 2)
VALUES TRUNC(-7 / 2.0);
-- COL1: -3

-- # RADIANS
-- # =RADIANS(180)
VALUES RADIANS(180e0);
-- COL1: 3.14159265359e0

-- # RAND
-- # =RAND()
VALUES RANDOM() < 1;
-- COL1: TRUE

-- # RANDBETWEEN
-- # =RANDBETWEEN(1, 6)
VALUES FLOOR(RANDOM() * (6 - 1 + 1)) + 1 BETWEEN 1 AND 6;
-- COL1: TRUE

-- # ROUND
-- # =ROUND(2.345, 2)
VALUES ROUND(2.345, 2);
-- COL1: 2.35

-- # ROUNDDOWN
-- # =ROUNDDOWN(2.789, 1)
VALUES TRUNC(2.789, 1);
-- COL1: 2.7

-- # ROUNDUP
-- # =ROUNDUP(2.341, 1)
VALUES SIGN(2.341) * CEIL(ABS(2.341) * 10) / 10.0;
-- COL1: 2.4

-- # SEC
-- # =SEC(1)
VALUES 1 / COS(1e0);
-- COL1: 1.850815717681e0

-- # SECH
-- # =SECH(1)
VALUES 1 / COSH(1e0);
-- COL1: 0.648054273664e0

-- # SERIESSUM
-- # =SERIESSUM(2, 0, 1, {1, 2, 3})
SELECT SUM(a * POWER(2, 0 + (i - 1) * 1))
FROM (VALUES (1, 1), (2, 2), (3, 3)) AS c (i, a);
-- COL1: 17e0

-- # SIGN
-- # =SIGN(-3)
VALUES SIGN(-3);
-- COL1: -1

-- # SIN
-- # =SIN(1)
VALUES SIN(1e0);
-- COL1: 0.841470984808e0

-- # SINH
-- # =SINH(1)
VALUES SINH(1e0);
-- COL1: 1.175201193644e0

-- # SQRT
-- # =SQRT(16)
VALUES SQRT(16e0);
-- COL1: 4e0

-- # SQRTPI
-- # =SQRTPI(2)
VALUES SQRT(2 * PI());
-- COL1: 2.506628274631e0

-- # SUBTOTAL
-- # =SUBTOTAL(1, B2:B5)
SELECT AVG(y) FROM points;
-- COL1: 5.05e0

-- # SUM
-- # =SUM(C2:C5)
SELECT SUM(price) FROM products;
-- COL1: 8.75

-- # SUM
-- # =SUM(1, 2, 3)
VALUES 1 + 2 + 3;
-- COL1: 6

-- # SUMIF
-- # =SUMIF(C2:C5, "<2", D2:D5)
SELECT SUM(qty) FILTER (WHERE price < 2) FROM products;
-- COL1: 50

-- # SUMIF
-- # =SUMIF(C2:C5, "<2")
SELECT SUM(price) FILTER (WHERE price < 2) FROM products;
-- COL1: 1.75

-- # SUMIFS
-- # =SUMIFS(D2:D5, C2:C5, "<2", B2:B5, "B*")
SELECT SUM(qty) FILTER (WHERE price < 2 AND name LIKE 'B%') FROM products;
-- COL1: 40

-- # SUMPRODUCT
-- # =SUMPRODUCT(A2:A5, B2:B5)
SELECT SUM(x * y) FROM points;
-- COL1: 60.7e0

-- # SUMSQ
-- # =SUMSQ(A2:A5)
SELECT SUM(x * x) FROM points;
-- COL1: 30e0

-- # SUMX2MY2
-- # =SUMX2MY2(A2:A5, B2:B5)
SELECT SUM(x * x - y * y) FROM points;
-- COL1: -92.86e0

-- # SUMX2PY2
-- # =SUMX2PY2(A2:A5, B2:B5)
SELECT SUM(x * x + y * y) FROM points;
-- COL1: 152.86e0

-- # SUMXMY2
-- # =SUMXMY2(A2:A5, B2:B5)
SELECT SUM((x - y) * (x - y)) FROM points;
-- COL1: 31.46e0

-- # TAN
-- # =TAN(1)
VALUES TAN(1e0);
-- COL1: 1.557407724655e0

-- # TANH
-- # =TANH(1)
VALUES TANH(1e0);
-- COL1: 0.761594155956e0

-- # TRUNC
-- # =TRUNC(-4.37, 1)
VALUES TRUNC(-4.37, 1);
-- COL1: -4.3

-- # TRUNC
-- # =TRUNC(-4.37)
VALUES TRUNC(-4.37);
-- COL1: -4

-- # ADD
-- # =ADD(2, 3)
VALUES 2 + 3;
-- COL1: 5

-- # DIVIDE
-- # =DIVIDE(10, 4)
VALUES 10 / 4.0;
-- COL1: 2.5

-- # EQ
-- # =EQ(2, 2)
VALUES 2 = 2;
-- COL1: TRUE

-- # GT
-- # =GT(3, 2)
VALUES 3 > 2;
-- COL1: TRUE

-- # GTE
-- # =GTE(2, 2)
VALUES 2 >= 2;
-- COL1: TRUE

-- # ISBETWEEN
-- # =ISBETWEEN(5, 1, 10)
VALUES 5 BETWEEN 1 AND 10;
-- COL1: TRUE

-- # ISBETWEEN
-- # =ISBETWEEN(10, 1, 10, FALSE, FALSE)
VALUES 10 > 1 AND 10 < 10;
-- COL1: FALSE

-- # LT
-- # =LT(2, 3)
VALUES 2 < 3;
-- COL1: TRUE

-- # LTE
-- # =LTE(3, 2)
VALUES 3 <= 2;
-- COL1: FALSE

-- # MINUS
-- # =MINUS(5, 3)
VALUES 5 - 3;
-- COL1: 2

-- # MULTIPLY
-- # =MULTIPLY(4, 2.5)
VALUES 4 * 2.5;
-- COL1: 10.0

-- # NE
-- # =NE(2, 3)
VALUES 2 <> 3;
-- COL1: TRUE

-- # POW
-- # =POW(2, 10)
VALUES POWER(2, 10);
-- COL1: 1024e0

-- # UMINUS
-- # =UMINUS(5)
VALUES -5;
-- COL1: -5

-- # UNARY_PERCENT
-- # =UNARY_PERCENT(25)
VALUES 25 * 0.01;
-- COL1: 0.25

-- # UPLUS
-- # =UPLUS(5)
VALUES +5;
-- COL1: 5

-- # TO_DOLLARS
-- # =TO_DOLLARS(1.5)
VALUES '$' || CAST(CAST(1.5 AS DECIMAL(10, 2)) AS VARCHAR(20));
-- COL1: $1.50

-- # TO_PERCENT
-- # =TO_PERCENT(0.25)
VALUES CAST(CAST(0.25 * 100 AS DECIMAL(10, 0)) AS VARCHAR(20)) || '%';
-- COL1: 25%

-- # TO_PURE_NUMBER
-- # =TO_PURE_NUMBER(TO_PERCENT(0.25))
VALUES 0.25;
-- COL1: 0.25

-- # TO_TEXT
-- # =TO_TEXT(24)
VALUES CAST(24 AS VARCHAR(20));
-- COL1: 24

-- # AVEDEV
-- # =AVEDEV(B2:B5)
SELECT AVG(ABS(y - a))
FROM points, (SELECT AVG(y) AS a FROM points) AS m;
-- COL1: 2e0

-- # AVERAGE
-- # =AVERAGE(C2:C5)
SELECT AVG(CAST(price AS DOUBLE PRECISION)) FROM products;
-- COL1: 2.1875e0

-- # AVERAGE.WEIGHTED
-- # =AVERAGE.WEIGHTED(C2:C4, D2:D4)
SELECT SUM(price * qty) * 1e0 / SUM(qty) FROM products
WHERE qty IS NOT NULL;
-- COL1: 0.818181818182e0

-- # AVERAGEA
-- # =AVERAGEA(D2:D5)
SELECT AVG(CAST(COALESCE(qty, 0) AS DOUBLE PRECISION))
FROM products;
-- COL1: 13.75e0

-- # AVERAGEIF
-- # =AVERAGEIF(A2:A5, ">2", B2:B5)
SELECT AVG(y) FILTER (WHERE x > 2) FROM points;
-- COL1: 7.05e0

-- # AVERAGEIFS
-- # =AVERAGEIFS(B2:B5, A2:A5, ">1", A2:A5, "<4")
SELECT AVG(y) FILTER (WHERE x > 1 AND x < 4) FROM points;
-- COL1: 5e0

-- # BINOM.DIST
-- # =BINOM.DIST(2, 5, 0.5, FALSE)
VALUES FACTORIAL(5) / (FACTORIAL(2) * FACTORIAL(5 - 2))
  * POWER(0.5e0, 2) * POWER(1 - 0.5e0, 5 - 2);
-- COL1: 0.3125e0

-- # BINOM.DIST.RANGE
-- # =BINOM.DIST.RANGE(3, 0.5, 1, 2)
SELECT SUM(FACTORIAL(3) / (FACTORIAL(k) * FACTORIAL(3 - k))
  * POWER(0.5e0, k) * POWER(1 - 0.5e0, 3 - k))
FROM (VALUES 1, 2) AS t (k);
-- COL1: 0.75e0

-- # CORREL
-- # =CORREL(B2:B5, A2:A5)
SELECT CORR(y, x) FROM points;
-- COL1: 0.998992298024e0

-- # COUNT
-- # =COUNT(C2:C5)
SELECT COUNT(price) FROM products;
-- COL1: 4

-- # COUNTA
-- # =COUNTA(A2:A5)
SELECT COUNT(sku) FROM products;
-- COL1: 4

-- # COUNTBLANK
-- # =COUNTBLANK(D2:D5)
SELECT COUNT(*) FILTER (WHERE qty IS NULL) FROM products;
-- COL1: 1

-- # COUNTIF
-- # =COUNTIF(C2:C5, ">2")
SELECT COUNT(*) FILTER (WHERE price > 2) FROM products;
-- COL1: 2

-- # COUNTIFS
-- # =COUNTIFS(C2:C5, ">1", D2:D5, ">=10")
SELECT COUNT(*) FILTER (WHERE price > 1 AND qty >= 10)
FROM products;
-- COL1: 1

-- # COUNTUNIQUE
-- # =COUNTUNIQUE(1, 2, 2, 3)
SELECT COUNT(DISTINCT v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
-- COL1: 3

-- # COUNTUNIQUEIFS
-- # =COUNTUNIQUEIFS(B2:B5, C2:C5, ">1")
SELECT COUNT(DISTINCT name) FILTER (WHERE price > 1)
FROM products;
-- COL1: 3

-- # COVARIANCE.P
-- # =COVARIANCE.P(B2:B5, A2:A5)
SELECT COVAR_POP(y, x) FROM points;
-- COL1: 2.55e0

-- # COVARIANCE.S
-- # =COVARIANCE.S(B2:B5, A2:A5)
SELECT COVAR_SAMP(y, x) FROM points;
-- COL1: 3.4e0

-- # DEVSQ
-- # =DEVSQ(B2:B5)
SELECT VAR_POP(y) * COUNT(y) FROM points;
-- COL1: 20.85e0

-- # EXPON.DIST
-- # =EXPON.DIST(0.5, 2, TRUE)
VALUES 1 - EXP(-2 * 0.5e0);
-- COL1: 0.632120558829e0

-- # EXPON.DIST
-- # =EXPON.DIST(0.5, 2, FALSE)
VALUES 2 * EXP(-2 * 0.5e0);
-- COL1: 0.735758882343e0

-- # FISHER
-- # =FISHER(0.75)
VALUES 0.5 * LN((1 + 0.75e0) / (1 - 0.75e0));
-- COL1: 0.972955074528e0

-- # FISHERINV
-- # =FISHERINV(0.5)
VALUES TANH(0.5e0);
-- COL1: 0.46211715726e0

-- # FORECAST.LINEAR
-- # =FORECAST.LINEAR(5, B2:B5, A2:A5)
SELECT REGR_INTERCEPT(y, x) + REGR_SLOPE(y, x) * 5 FROM points;
-- COL1: 10.15e0

-- # FREQUENCY
-- # =FREQUENCY(C2:C5, {1; 3})
SELECT COUNT(*) FILTER (WHERE price <= 1) AS bin1,
       COUNT(*) FILTER (WHERE price > 1 AND price <= 3) AS bin2,
       COUNT(*) FILTER (WHERE price > 3) AS bin3
FROM products;
-- BIN1: 1 BIN2: 2 BIN3: 1

-- # GAMMA
-- # =GAMMA(2.5)
VALUES GAMMA(2.5);
-- COL1: 1.329340388179e0

-- # GAMMALN
-- # =GAMMALN(10)
VALUES LGAMMA(10);
-- COL1: 12.801827480081e0

-- # GAMMALN.PRECISE
-- # =GAMMALN.PRECISE(10)
VALUES LGAMMA(10);
-- COL1: 12.801827480081e0

-- # GAUSS
-- # =GAUSS(2)
VALUES ERF(2 / SQRT(2e0)) / 2;
-- COL1: 0.477249868052e0

-- # GEOMEAN
-- # =GEOMEAN(B2:B5)
SELECT EXP(AVG(LN(y))) FROM points;
-- COL1: 4.462928499813e0

-- # GROWTH
-- # =GROWTH(B2:B5, A2:A5, 5)
SELECT EXP(REGR_INTERCEPT(LN(y), x) + REGR_SLOPE(LN(y), x) * 5)
FROM points;
-- COL1: 14.0839625106e0

-- # HARMEAN
-- # =HARMEAN(B2:B5)
SELECT COUNT(y) / SUM(1 / y) FROM points;
-- COL1: 3.863445797564e0

-- # HYPGEOM.DIST
-- # =HYPGEOM.DIST(1, 2, 3, 6, FALSE)
VALUES (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
  * (FACTORIAL(3) / (FACTORIAL(1) * FACTORIAL(2)))
  / (FACTORIAL(6) / (FACTORIAL(2) * FACTORIAL(4)) * 1e0);
-- COL1: 0.6e0

-- # INTERCEPT
-- # =INTERCEPT(B2:B5, A2:A5)
SELECT REGR_INTERCEPT(y, x) FROM points;
-- COL1: -0.05e0

-- # KURT
-- # =KURT(B2:B5)
SELECT COUNT(*) * (COUNT(*) + 1) * SUM(POWER((y - a) / s, 4))
         / ((COUNT(*) - 1) * (COUNT(*) - 2) * (COUNT(*) - 3))
       - 3e0 * POWER(COUNT(*) - 1, 2) / ((COUNT(*) - 2) * (COUNT(*) - 3))
FROM points, (SELECT AVG(y) AS a, STDDEV_SAMP(y) AS s FROM points) AS m;
-- COL1: -0.641519590083e0

-- # LARGE
-- # =LARGE(C2:C5, 2)
SELECT price FROM products ORDER BY price DESC
OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
-- PRICE: 3.00

-- # LINEST
-- # =LINEST(B2:B5, A2:A5)
SELECT REGR_SLOPE(y, x) AS m, REGR_INTERCEPT(y, x) AS b FROM points;
-- M: 2.04e0 B: -0.05e0

-- # LOGEST
-- # =LOGEST(B2:B5, A2:A5)
SELECT EXP(REGR_SLOPE(LN(y), x)) AS m, EXP(REGR_INTERCEPT(LN(y), x)) AS b
FROM points;
-- M: 1.583587162731e0 B: 1.414213562373e0

-- # LOGNORM.DIST
-- # =LOGNORM.DIST(2, 0, 1, TRUE)
VALUES 0.5 * ERFC(-(LN(2e0) - 0) / (1e0 * SQRT(2e0)));
-- COL1: 0.755891404214e0

-- # LOGNORM.DIST
-- # =LOGNORM.DIST(2, 0, 1, FALSE)
VALUES EXP(-POWER(LN(2e0) - 0, 2) / (2 * POWER(1e0, 2)))
  / (2 * 1e0 * SQRT(2 * PI()));
-- COL1: 0.156874019279e0

-- # MAX
-- # =MAX(C2:C5)
SELECT MAX(price) FROM products;
-- COL1: 4.00

-- # MAXA
-- # =MAXA(D2:D5)
SELECT MAX(COALESCE(qty, 0)) FROM products;
-- COL1: 40

-- # MAXIFS
-- # =MAXIFS(C2:C5, D2:D5, ">=10")
SELECT MAX(price) FILTER (WHERE qty >= 10) FROM products;
-- COL1: 1.50

-- # MEDIAN
-- # =MEDIAN(C2:C5)
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
FROM products;
-- COL1: 2.25e0

-- # MIN
-- # =MIN(C2:C5)
SELECT MIN(price) FROM products;
-- COL1: 0.25

-- # MINA
-- # =MINA(D2:D5)
SELECT MIN(COALESCE(qty, 0)) FROM products;
-- COL1: 0

-- # MINIFS
-- # =MINIFS(C2:C5, D2:D5, ">=10")
SELECT MIN(price) FILTER (WHERE qty >= 10) FROM products;
-- COL1: 0.25

-- # MODE.MULT
-- # =MODE.MULT(1, 2, 2, 3, 3)
SELECT v FROM (VALUES (1), (2), (2), (3), (3)) AS t (v)
GROUP BY v HAVING COUNT(*) >= ALL (SELECT COUNT(*)
  FROM (VALUES (1), (2), (2), (3), (3)) AS u (v) GROUP BY v)
ORDER BY v;
-- V: 2
-- V: 3

-- # MODE.SNGL
/* extensions V405-01 */
-- # =MODE.SNGL(1, 2, 2, 3)
SELECT MODE() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
-- COL1: 2

-- # NEGBINOM.DIST
-- # =NEGBINOM.DIST(2, 3, 0.5, FALSE)
VALUES FACTORIAL(2 + 3 - 1) / (FACTORIAL(3 - 1) * FACTORIAL(2))
  * POWER(0.5e0, 3) * POWER(1 - 0.5e0, 2);
-- COL1: 0.1875e0

-- # NORM.DIST
-- # =NORM.DIST(1, 0, 1, TRUE)
VALUES 0.5 * ERFC(-(1 - 0) / (1e0 * SQRT(2e0)));
-- COL1: 0.841344746069e0

-- # NORM.DIST
-- # =NORM.DIST(1, 0, 1, FALSE)
VALUES EXP(-POWER(1 - 0, 2) / (2 * POWER(1e0, 2)))
  / (1e0 * SQRT(2 * PI()));
-- COL1: 0.241970724519e0

-- # NORM.S.DIST
-- # =NORM.S.DIST(1, TRUE)
VALUES 0.5 * ERFC(-1e0 / SQRT(2e0));
-- COL1: 0.841344746069e0

-- # NORM.S.DIST
-- # =NORM.S.DIST(1, FALSE)
VALUES EXP(-POWER(1e0, 2) / 2) / SQRT(2 * PI());
-- COL1: 0.241970724519e0

-- # PEARSON
-- # =PEARSON(B2:B5, A2:A5)
SELECT CORR(y, x) FROM points;
-- COL1: 0.998992298024e0

-- # PERCENTILE.EXC
-- # =PERCENTILE.EXC(B2:B5, 0.25)
SELECT PERCENTILE_CONT(((4 + 1) * 0.25e0 - 1) / (4 - 1))
  WITHIN GROUP (ORDER BY y) FROM points;
-- COL1: 2.525e0

-- # PERCENTILE.INC
-- # =PERCENTILE.INC(B2:B5, 0.25)
SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY y)
FROM points;
-- COL1: 3.575e0

-- # PERCENTRANK.EXC
-- # =PERCENTRANK.EXC(C2:C5, 3)
SELECT TRUNC((COUNT(*) FILTER (WHERE price < 3) + 1)
  / (COUNT(*) + 1e0), 3) FROM products;
-- COL1: 0.6e0

-- # PERCENTRANK.INC
-- # =PERCENTRANK.INC(C2:C5, 3)
SELECT TRUNC(COUNT(*) FILTER (WHERE price < 3)
  / (COUNT(*) - 1e0), 3) FROM products;
-- COL1: 0.666e0

-- # PERMUT
-- # =PERMUT(5, 2)
VALUES FACTORIAL(5) / FACTORIAL(5 - 2);
-- COL1: 20

-- # PERMUTATIONA
-- # =PERMUTATIONA(5, 2)
VALUES POWER(5, 2);
-- COL1: 25e0

-- # PHI
-- # =PHI(0.75)
VALUES EXP(-POWER(0.75e0, 2) / 2) / SQRT(2 * PI());
-- COL1: 0.301137432155e0

-- # POISSON.DIST
-- # =POISSON.DIST(2, 3, FALSE)
VALUES EXP(-3e0) * POWER(3e0, 2) / FACTORIAL(2);
-- COL1: 0.224041807655e0

-- # PROB
-- # =PROB({0; 1; 2; 3}, {0.2; 0.3; 0.1; 0.4}, 1, 2)
SELECT SUM(p) FROM (VALUES (0, 0.2), (1, 0.3), (2, 0.1), (3, 0.4))
  AS t (x, p) WHERE x BETWEEN 1 AND 2;
-- COL1: 0.4

-- # PROB
-- # =PROB({0; 1; 2; 3}, {0.2; 0.3; 0.1; 0.4}, 1)
SELECT SUM(p) FROM (VALUES (0, 0.2), (1, 0.3), (2, 0.1), (3, 0.4)) AS t (x, p) WHERE x = 1;
-- COL1: 0.3

-- # QUARTILE.EXC
-- # =QUARTILE.EXC(B2:B5, 1)
SELECT PERCENTILE_CONT(((4 + 1) * 0.25e0 - 1) / (4 - 1))
  WITHIN GROUP (ORDER BY y) FROM points;
-- COL1: 2.525e0

-- # QUARTILE.INC
-- # =QUARTILE.INC(B2:B5, 1)
SELECT PERCENTILE_CONT(1 / 4e0) WITHIN GROUP (ORDER BY y)
FROM points;
-- COL1: 3.575e0

-- # RANK.AVG
-- # =RANK.AVG(3, C2:C5)
SELECT COUNT(*) FILTER (WHERE price > 3)
  + (COUNT(*) FILTER (WHERE price = 3) + 1) / 2.0 FROM products;
-- COL1: 2.0

-- # RANK.EQ
-- # =RANK.EQ(3, C2:C5)
SELECT RANK(3) WITHIN GROUP (ORDER BY price DESC)
FROM products;
-- COL1: 2

-- # RANK.EQ
-- # =RANK.EQ(3, C2:C5, 1)
SELECT RANK(3) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 3

-- # RSQ
-- # =RSQ(B2:B5, A2:A5)
SELECT REGR_R2(y, x) FROM points;
-- COL1: 0.997985611511e0

-- # SKEW
-- # =SKEW(B2:B5)
SELECT COUNT(*) * SUM(POWER((y - a) / s, 3))
       / ((COUNT(*) - 1) * (COUNT(*) - 2))
FROM points, (SELECT AVG(y) AS a, STDDEV_SAMP(y) AS s FROM points) AS m;
-- COL1: 0.096058424862e0

-- # SKEW.P
-- # =SKEW.P(B2:B5)
SELECT AVG(POWER((y - a) / s, 3))
FROM points, (SELECT AVG(y) AS a, STDDEV_POP(y) AS s FROM points) AS m;
-- COL1: 0.055459357452e0

-- # SLOPE
-- # =SLOPE(B2:B5, A2:A5)
SELECT REGR_SLOPE(y, x) FROM points;
-- COL1: 2.04e0

-- # SMALL
-- # =SMALL(C2:C5, 2)
SELECT price FROM products ORDER BY price
OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
-- PRICE: 1.50

-- # STANDARDIZE
-- # =STANDARDIZE(42, 40, 1.5)
VALUES (42 - 40) / 1.5e0;
-- COL1: 1.333333333333e0

-- # STDEV.P
-- # =STDEV.P(B2:B5)
SELECT STDDEV_POP(y) FROM points;
-- COL1: 2.283090011366e0

-- # STDEV.S
-- # =STDEV.S(B2:B5)
SELECT STDDEV_SAMP(y) FROM points;
-- COL1: 2.636285265293e0

-- # STDEVA
-- # =STDEVA(D2:D5)
SELECT STDDEV_SAMP(COALESCE(qty, 0)) FROM products;
-- COL1: 17.969882210707e0

-- # STDEVPA
-- # =STDEVPA(D2:D5)
SELECT STDDEV_POP(COALESCE(qty, 0)) FROM products;
-- COL1: 15.562374497486e0

-- # STEYX
-- # =STEYX(B2:B5, A2:A5)
SELECT SQRT((REGR_SYY(y, x) - POWER(REGR_SXY(y, x), 2) / REGR_SXX(y, x))
  / (REGR_COUNT(y, x) - 2)) FROM points;
-- COL1: 0.144913767462e0

-- # TREND
-- # =TREND(B2:B5, A2:A5, 5)
SELECT REGR_INTERCEPT(y, x) + REGR_SLOPE(y, x) * 5 FROM points;
-- COL1: 10.15e0

-- # TRIMMEAN
-- # =TRIMMEAN(C2:C5, 0.5)
SELECT AVG(price) FROM (SELECT price FROM products ORDER BY price
  OFFSET 1 ROW FETCH FIRST 2 ROWS ONLY) AS t;
-- COL1: 2.25

-- # VAR.P
-- # =VAR.P(B2:B5)
SELECT VAR_POP(y) FROM points;
-- COL1: 5.2125e0

-- # VAR.S
-- # =VAR.S(B2:B5)
SELECT VAR_SAMP(y) FROM points;
-- COL1: 6.95e0

-- # VARA
-- # =VARA(D2:D5)
SELECT VAR_SAMP(COALESCE(qty, 0)) FROM products;
-- COL1: 322.916666666667e0

-- # VARPA
-- # =VARPA(D2:D5)
SELECT VAR_POP(COALESCE(qty, 0)) FROM products;
-- COL1: 242.1875e0

-- # WEIBULL.DIST
-- # =WEIBULL.DIST(2, 1.5, 3, TRUE)
VALUES 1 - EXP(-POWER(2 / 3e0, 1.5));
-- COL1: 0.419770204025e0

-- # Z.TEST
-- # =Z.TEST(B2:B5, 4)
SELECT 0.5 * ERFC((AVG(y) - 4) / (STDDEV_SAMP(y) / SQRT(COUNT(y))) / SQRT(2e0))
FROM points;
-- COL1: 0.212848833428e0

-- # Z.TEST
-- # =Z.TEST(B2:B5, 4, 2)
SELECT 0.5 * ERFC((AVG(y) - 4) / (2 / SQRT(COUNT(y))) / SQRT(2e0))
FROM points;
-- COL1: 0.146859056376e0

-- # ARRAYTOTEXT
-- # =ARRAYTOTEXT(B2:B5)
SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY sku) FROM products;
-- COL1: Apple, Banana, Cherry, Date

-- # CHAR
-- # =CHAR(65)
VALUES CHR(65);
-- COL1: A

-- # CODE
-- # =CODE("Apple")
VALUES UNICODE('Apple');
-- COL1: 65

-- # CONCAT
-- # =CONCAT("Apple", "pie")
VALUES 'Apple' || 'pie';
-- COL1: Applepie

-- # CONCATENATE
-- # =CONCATENATE("Apple", "pie")
VALUES 'Apple' || 'pie';
-- COL1: Applepie

-- # DOLLAR
-- # =DOLLAR(4.5)
VALUES '$' || CAST(CAST(ROUND(4.5, 2) AS DECIMAL(10, 2)) AS VARCHAR(20));
-- COL1: $4.50

-- # EXACT
-- # =EXACT("Apple", "apple")
VALUES 'Apple' = 'apple';
-- COL1: FALSE

-- # FIND
-- # =FIND("p", "Apple")
VALUES POSITION('p' IN 'Apple');
-- COL1: 2

-- # FIXED
-- # =FIXED(1234.567, 1, TRUE)
VALUES CAST(CAST(ROUND(1234.567, 1) AS DECIMAL(10, 1)) AS VARCHAR(20));
-- COL1: 1234.6

-- # JOIN
-- # =JOIN(", ", B2:B5)
SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY sku) FROM products;
-- COL1: Apple, Banana, Cherry, Date

-- # LEFT
-- # =LEFT("Apple", 3)
VALUES SUBSTRING('Apple' FROM 1 FOR 3);
-- COL1: App

-- # LEFT
-- # =LEFT("Apple")
VALUES SUBSTRING('Apple' FROM 1 FOR 1);
-- COL1: A

-- # LEFTB
-- # =LEFTB("Apple", 3)
VALUES SUBSTRING('Apple' FROM 1 FOR 3 USING OCTETS);
-- COL1: App

-- # LEN
-- # =LEN("Apple")
VALUES CHAR_LENGTH('Apple');
-- COL1: 5

-- # LENB
-- # =LENB("Apple")
VALUES OCTET_LENGTH('Apple');
-- COL1: 5

-- # LOWER
-- # =LOWER("Apple")
VALUES LOWER('Apple');
-- COL1: apple

-- # MID
-- # =MID("Apple", 2, 3)
VALUES SUBSTRING('Apple' FROM 2 FOR 3);
-- COL1: ppl

-- # MIDB
-- # =MIDB("Apple", 2, 3)
VALUES SUBSTRING('Apple' FROM 2 FOR 3 USING OCTETS);
-- COL1: ppl

-- # NUMBERVALUE
-- # =NUMBERVALUE("1234.5")
VALUES CAST('1234.5' AS DECIMAL(10, 2));
-- COL1: 1234.50

-- # PROPER
-- # =PROPER("hELLO wORLD")
VALUES INITCAP('hELLO wORLD');
-- COL1: Hello World

-- # REGEXMATCH
-- # =REGEXMATCH("Apple", "^[AB]")
VALUES 'Apple' SIMILAR TO '[AB]%';
-- COL1: TRUE

-- # REGEXTEST
-- # =REGEXTEST("Apple", "^[AB]")
VALUES 'Apple' SIMILAR TO '[AB]%';
-- COL1: TRUE

-- # REPLACE
-- # =REPLACE("Apple", 2, 3, "xx")
VALUES OVERLAY('Apple' PLACING 'xx' FROM 2 FOR 3);
-- COL1: Axxe

-- # REPLACEB
-- # =REPLACEB("Apple", 2, 3, "xx")
VALUES OVERLAY('Apple' PLACING 'xx' FROM 2 FOR 3 USING OCTETS);
-- COL1: Axxe

-- # REPT
-- # =REPT("ab", 3)
VALUES REPEAT('ab', 3);
-- COL1: ababab

-- # RIGHT
-- # =RIGHT("Apple", 2)
VALUES SUBSTRING('Apple' FROM CHAR_LENGTH('Apple') - 2 + 1);
-- COL1: le

-- # RIGHT
-- # =RIGHT("Apple")
VALUES SUBSTRING('Apple' FROM CHAR_LENGTH('Apple'));
-- COL1: e

-- # RIGHTB
-- # =RIGHTB("Apple", 2)
VALUES SUBSTRING('Apple' FROM OCTET_LENGTH('Apple') - 2 + 1 USING OCTETS);
-- COL1: le

-- # SEARCH
-- # =SEARCH("P", "Apple")
VALUES POSITION(UPPER('P') IN UPPER('Apple'));
-- COL1: 2

-- # SPLIT
-- # =INDEX(SPLIT("a,b,c", ","), 1, 2)
VALUES SPLIT_PART('a,b,c', ',', 2);
-- COL1: b

-- # SUBSTITUTE
-- # =SUBSTITUTE("Apple", "p", "b")
VALUES REPLACE('Apple', 'p', 'b');
-- COL1: Abble

-- # TEXTAFTER
-- # =TEXTAFTER("user@example.com", "@")
VALUES SUBSTRING('user@example.com' FROM POSITION('@' IN 'user@example.com') + CHAR_LENGTH('@'));
-- COL1: example.com

-- # TEXTAFTER
-- # =TEXTAFTER("www.example.com", ".", -1)
VALUES SPLIT_PART('www.example.com', '.', -1);
-- COL1: com

-- # TEXTBEFORE
-- # =TEXTBEFORE("user@example.com", "@")
VALUES SPLIT_PART('user@example.com', '@', 1);
-- COL1: user

-- # TEXTJOIN
-- # =TEXTJOIN(", ", TRUE, D2:D5)
SELECT LISTAGG(CAST(qty AS VARCHAR(10)), ', ') WITHIN GROUP (ORDER BY sku)
FROM products WHERE qty IS NOT NULL;
-- COL1: 10, 40, 5

-- # TEXTSPLIT
-- # =INDEX(TEXTSPLIT("a,b,c", ","), 1, 2)
VALUES SPLIT_PART('a,b,c', ',', 2);
-- COL1: b

-- # TRIM
-- # =TRIM("  Apple  ")
VALUES TRIM('  Apple  ');
-- COL1: Apple

-- # UNICHAR
-- # =UNICHAR(8364)
VALUES CHR(8364);
-- COL1: €

-- # UNICODE
-- # =UNICODE("€")
VALUES UNICODE('€');
-- COL1: 8364

-- # UPPER
-- # =UPPER("Apple")
VALUES UPPER('Apple');
-- COL1: APPLE

-- # VALUE
-- # =VALUE("12.5")
VALUES CAST('12.5' AS DECIMAL(10, 2));
-- COL1: 12.50

-- # VALUETOTEXT
-- # =VALUETOTEXT(12.5)
VALUES CAST(12.5 AS VARCHAR(10));
-- COL1: 12.5
