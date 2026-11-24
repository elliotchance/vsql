-- # The examples of docs/compatibility-mysql.rst, one test per function.
-- # Each example runs with the example table of the page.

/* setup */
CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);

-- # COALESCE
-- # COALESCE(NULL, 'b', 'c')
VALUES COALESCE(CAST(NULL AS VARCHAR(5)), 'b', 'c');
-- COL1: b

-- # GREATEST
-- # GREATEST(2, 34, 7)
VALUES GREATEST(2, 34, 7);
-- COL1: 34

-- # INTERVAL
-- # INTERVAL(23, 1, 15, 30)
VALUES CASE WHEN 23 < 1 THEN 0 WHEN 23 < 15 THEN 1 WHEN 23 < 30 THEN 2 ELSE 3 END;
-- COL1: 2

-- # ISNULL
-- # SELECT ISNULL(qty) FROM products WHERE sku = 'D4'
SELECT qty IS NULL FROM products WHERE sku = 'D4';
-- COL1: TRUE

-- # LEAST
-- # LEAST('B', 'A', 'C')
VALUES LEAST('B', 'A', 'C');
-- COL1: A

-- # IF
-- # IF(1 < 2, 'yes', 'no')
VALUES CASE WHEN 1 < 2 THEN 'yes' ELSE 'no' END;
-- COL1: yes

-- # IFNULL
-- # IFNULL(NULL, 'none')
VALUES COALESCE(CAST(NULL AS VARCHAR(10)), 'none');
-- COL1: none

-- # NULLIF
-- # NULLIF(1, 2)
VALUES NULLIF(1, 2);
-- COL1: 1

-- # ABS
-- # ABS(-32)
VALUES ABS(-32);
-- COL1: 32

-- # ACOS
-- # ACOS(0.5)
VALUES ACOS(0.5);
-- COL1: 1.047197551197e0

-- # ASIN
-- # ASIN(0.2)
VALUES ASIN(0.2);
-- COL1: 0.20135792079e0

-- # ATAN
-- # ATAN(2)
VALUES ATAN(2);
-- COL1: 1.107148717794e0

-- # ATAN
-- # ATAN(-2, 2)
VALUES ATAN2(-2, 2);
-- COL1: -0.785398163397e0

-- # ATAN2
-- # ATAN2(-2, 2)
VALUES ATAN2(-2, 2);
-- COL1: -0.785398163397e0

-- # CEIL
-- # CEIL(1.23)
VALUES CEIL(1.23);
-- COL1: 2

-- # CEILING
-- # CEILING(-1.23)
VALUES CEILING(-1.23);
-- COL1: -1

-- # COS
-- # COS(1)
VALUES COS(1);
-- COL1: 0.540302305868e0

-- # COT
-- # COT(12)
VALUES 1 / TAN(12);
-- COL1: -1.572673406398e0

-- # DEGREES
-- # DEGREES(1)
VALUES DEGREES(1);
-- COL1: 57.295779513082e0

-- # EXP
-- # EXP(2)
VALUES EXP(2);
-- COL1: 7.389056098931e0

-- # FLOOR
-- # FLOOR(-1.23)
VALUES FLOOR(-1.23);
-- COL1: -2

-- # LN
-- # LN(2)
VALUES LN(2);
-- COL1: 0.69314718056e0

-- # LOG
-- # LOG(2)
VALUES LN(2);
-- COL1: 0.69314718056e0

-- # LOG
-- # LOG(2, 65536)
VALUES LOG(2, 65536);
-- COL1: 16e0

-- # LOG10
-- # LOG10(100)
VALUES LOG10(100);
-- COL1: 2e0

-- # LOG2
-- # LOG2(65536)
VALUES LOG(2, 65536);
-- COL1: 16e0

-- # MOD
-- # MOD(234, 10)
VALUES MOD(234, 10);
-- COL1: 4

-- # PI
-- # PI()
VALUES PI();
-- COL1: 3.14159265359e0

-- # POW
-- # POW(2, 2)
VALUES POWER(2, 2);
-- COL1: 4e0

-- # POWER
-- # POWER(2, -2)
VALUES POWER(2, -2);
-- COL1: 0.25e0

-- # RADIANS
-- # RADIANS(90)
VALUES RADIANS(90);
-- COL1: 1.570796326795e0

-- # RAND
-- # RAND() < 1
VALUES RANDOM() < 1;
-- COL1: TRUE

-- # ROUND
-- # ROUND(-1.58)
VALUES ROUND(-1.58);
-- COL1: -2

-- # ROUND
-- # ROUND(1.298, 1)
VALUES ROUND(1.298, 1);
-- COL1: 1.3

-- # SIGN
-- # SIGN(-32)
VALUES SIGN(-32);
-- COL1: -1

-- # SIN
-- # SIN(1)
VALUES SIN(1);
-- COL1: 0.841470984808e0

-- # SQRT
-- # SQRT(4)
VALUES SQRT(4);
-- COL1: 2e0

-- # TAN
-- # TAN(1)
VALUES TAN(1);
-- COL1: 1.557407724655e0

-- # TRUNCATE
-- # TRUNCATE(1.223, 1)
VALUES TRUNC(1.223, 1);
-- COL1: 1.2

-- # CURDATE
-- # CURDATE() > '2020-01-01'
VALUES CURRENT_DATE > DATE '2020-01-01';
-- COL1: TRUE

-- # CURRENT_DATE
-- # CURRENT_DATE() > '2020-01-01'
VALUES CURRENT_DATE > DATE '2020-01-01';
-- COL1: TRUE

-- # CURRENT_TIME
-- # CURRENT_TIME() >= '00:00:00'
VALUES LOCALTIME >= TIME '00:00:00';
-- COL1: TRUE

-- # CURRENT_TIMESTAMP
-- # CURRENT_TIMESTAMP() > '2020-01-01 00:00:00'
VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # CURTIME
-- # CURTIME() >= '00:00:00'
VALUES LOCALTIME >= TIME '00:00:00';
-- COL1: TRUE

-- # DATE
-- # DATE('2024-03-15 10:20:30')
VALUES CAST(TIMESTAMP '2024-03-15 10:20:30' AS DATE);
-- COL1: 2024-03-15

-- # DATEDIFF
-- # DATEDIFF('2024-03-15 23:00:00', '2024-03-01 08:00:00')
/* extensions V402-08 */
VALUES (EXTRACT(EPOCH FROM CAST(TIMESTAMP '2024-03-15 23:00:00' AS DATE))
  - EXTRACT(EPOCH FROM CAST(TIMESTAMP '2024-03-01 08:00:00' AS DATE))) / 86400;
-- COL1: 14.0000000000000000

-- # DATE_FORMAT
-- # DATE_FORMAT('2024-03-15 10:30:00', '%Y-%m-%d %H:%i')
VALUES CAST(TIMESTAMP '2024-03-15 10:30:00' AS VARCHAR(16) FORMAT 'YYYY-MM-DD HH24:MI');
-- COL1: 2024-03-15 10:30

-- # DAY
-- # DAY('2024-03-05')
VALUES EXTRACT(DAY FROM DATE '2024-03-05');
-- COL1: 5

-- # DAYOFMONTH
-- # DAYOFMONTH('2024-03-05')
VALUES EXTRACT(DAY FROM DATE '2024-03-05');
-- COL1: 5

-- # DAYOFWEEK
-- # DAYOFWEEK('2024-03-05')
/* extensions V402-02 */
VALUES EXTRACT(DOW FROM DATE '2024-03-05') + 1;
-- COL1: 3

-- # DAYOFYEAR
-- # DAYOFYEAR('2024-03-05')
/* extensions V402-04 */
VALUES EXTRACT(DOY FROM DATE '2024-03-05');
-- COL1: 65

-- # EXTRACT
-- # EXTRACT(YEAR FROM '2024-03-05')
VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
-- COL1: 2024

-- # HOUR
-- # HOUR('10:05:03')
VALUES EXTRACT(HOUR FROM TIME '10:05:03');
-- COL1: 10

-- # LOCALTIME
-- # LOCALTIME() > '2020-01-01 00:00:00'
VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # LOCALTIMESTAMP
-- # LOCALTIMESTAMP() > '2020-01-01 00:00:00'
VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # MAKETIME
-- # MAKETIME(12, 15, 30)
VALUES MAKE_TIME(12, 15, 30);
-- COL1: 12:15:30.000000

-- # MICROSECOND
-- # MICROSECOND('12:00:00.123456')
VALUES CAST(MOD(EXTRACT(SECOND FROM TIME '12:00:00.123456') * 1000000, 1000000) AS INTEGER);
-- COL1: 123456

-- # MINUTE
-- # MINUTE('10:05:03')
VALUES EXTRACT(MINUTE FROM TIME '10:05:03');
-- COL1: 5

-- # MONTH
-- # MONTH('2024-03-05')
VALUES EXTRACT(MONTH FROM DATE '2024-03-05');
-- COL1: 3

-- # NOW
-- # NOW() > '2020-01-01 00:00:00'
VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # PERIOD_ADD
-- # PERIOD_ADD(202311, 3)
VALUES (202311 / 100 * 12 + MOD(202311, 100) - 1 + 3) / 12 * 100
  + MOD(202311 / 100 * 12 + MOD(202311, 100) - 1 + 3, 12) + 1;
-- COL1: 202402

-- # PERIOD_DIFF
-- # PERIOD_DIFF(202403, 202310)
VALUES (202403 / 100 * 12 + MOD(202403, 100)) - (202310 / 100 * 12 + MOD(202310, 100));
-- COL1: 5

-- # QUARTER
-- # QUARTER('2024-08-05')
/* extensions V402-07 */
VALUES EXTRACT(QUARTER FROM DATE '2024-08-05');
-- COL1: 3

-- # SECOND
-- # SECOND('10:05:03')
VALUES EXTRACT(SECOND FROM TIME '10:05:03');
-- COL1: 3

-- # SEC_TO_TIME
-- # SEC_TO_TIME(2378)
VALUES CAST(MAKE_TIME(2378 / 3600, MOD(2378 / 60, 60), MOD(2378, 60)) AS TIME(0));
-- COL1: 00:39:38

-- # STR_TO_DATE
-- # STR_TO_DATE('15/03/2024 10:30', '%d/%m/%Y %H:%i')
VALUES CAST('15/03/2024 10:30' AS TIMESTAMP(0) FORMAT 'DD/MM/YYYY HH24:MI');
-- COL1: 2024-03-15T10:30:00

-- # SYSDATE
-- # SYSDATE() > '2020-01-01 00:00:00'
/* extensions V402-01 */
VALUES CAST(NOW() AS TIMESTAMP(0)) > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # TIME
-- # TIME('2024-03-15 10:20:30')
VALUES CAST(TIMESTAMP '2024-03-15 10:20:30' AS TIME);
-- COL1: 10:20:30

-- # TIMESTAMP
-- # TIMESTAMP('2024-03-15')
VALUES CAST(DATE '2024-03-15' AS TIMESTAMP(0));
-- COL1: 2024-03-15T00:00:00

-- # TIME_FORMAT
-- # TIME_FORMAT('22:23:00', '%h:%i %p')
VALUES CAST(TIME '22:23:00' AS VARCHAR(10) FORMAT 'HH12:MI A.M.');
-- COL1: 10:23 P.M.

-- # TIME_TO_SEC
-- # TIME_TO_SEC('22:23:00')
VALUES EXTRACT(HOUR FROM TIME '22:23:00') * 3600 + EXTRACT(MINUTE FROM TIME '22:23:00') * 60
  + EXTRACT(SECOND FROM TIME '22:23:00');
-- COL1: 80580

-- # TO_DAYS
-- # TO_DAYS('2024-03-05')
/* extensions V402-08 */
VALUES EXTRACT(EPOCH FROM DATE '2024-03-05') / 86400 + 719528;
-- COL1: 739315.0000000000000000

-- # TO_SECONDS
-- # TO_SECONDS('2024-03-05 10:20:30')
/* extensions V402-08 */
VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 10:20:30') + 62167219200;
-- COL1: 63876853230

-- # UNIX_TIMESTAMP
-- # UNIX_TIMESTAMP() > 1577836800
/* extensions V402-08 */
VALUES FLOOR(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP(0))) > 1577836800;
-- COL1: TRUE

-- # UNIX_TIMESTAMP
-- # UNIX_TIMESTAMP('2024-03-05 10:20:30')
/* extensions V402-08 */
VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 10:20:30');
-- COL1: 1709634030

-- # WEEK
-- # WEEK('2024-03-05')
/* extensions V402-02 V402-04 */
VALUES (EXTRACT(DOY FROM DATE '2024-03-05') - EXTRACT(DOW FROM DATE '2024-03-05') + 6) / 7;
-- COL1: 9

-- # WEEK
-- # WEEK('2027-01-01', 3)
/* extensions V402-05 */
VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
-- COL1: 53

-- # WEEKDAY
-- # WEEKDAY('2024-03-05')
/* extensions V402-03 */
VALUES EXTRACT(ISODOW FROM DATE '2024-03-05') - 1;
-- COL1: 1

-- # WEEKOFYEAR
-- # WEEKOFYEAR('2027-01-01')
/* extensions V402-05 */
VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
-- COL1: 53

-- # YEAR
-- # YEAR('2024-03-05')
VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
-- COL1: 2024

-- # YEARWEEK
-- # YEARWEEK('2027-01-01', 3)
/* extensions V402-05 V402-06 */
VALUES EXTRACT(ISOYEAR FROM DATE '2027-01-01') * 100 + EXTRACT(WEEK FROM DATE '2027-01-01');
-- COL1: 202653

-- # ASCII
-- # ASCII('dx')
VALUES UNICODE('dx');
-- COL1: 100

-- # BIT_LENGTH
-- # BIT_LENGTH('text')
VALUES OCTET_LENGTH('text') * 8;
-- COL1: 32

-- # CHAR
-- # CHAR(77, 121, 83, 81, 76)
VALUES CHR(77) || CHR(121) || CHR(83) || CHR(81) || CHR(76);
-- COL1: MySQL

-- # CHARACTER_LENGTH
-- # CHARACTER_LENGTH('héllo')
VALUES CHARACTER_LENGTH('héllo');
-- COL1: 5

-- # CHAR_LENGTH
-- # CHAR_LENGTH('héllo')
VALUES CHAR_LENGTH('héllo');
-- COL1: 5

-- # CONCAT
-- # CONCAT('My', 'S', 'QL')
VALUES CONCAT('My', 'S', 'QL');
-- COL1: MySQL

-- # CONCAT_WS
-- # CONCAT_WS(',', 'First name', 'Last Name')
VALUES CONCAT_WS(',', 'First name', 'Last Name');
-- COL1: First name,Last Name

-- # ELT
-- # ELT(2, 'Aa', 'Bb', 'Cc')
VALUES CASE 2 WHEN 1 THEN 'Aa' WHEN 2 THEN 'Bb' WHEN 3 THEN 'Cc' END;
-- COL1: Bb

-- # FIELD
-- # FIELD('Bb', 'Aa', 'Bb', 'Cc')
VALUES CASE 'Bb' WHEN 'Aa' THEN 1 WHEN 'Bb' THEN 2 WHEN 'Cc' THEN 3 ELSE 0 END;
-- COL1: 2

-- # FIND_IN_SET
-- # FIND_IN_SET('b', 'a,b,c')
VALUES CASE 'b' WHEN SPLIT_PART('a,b,c', ',', 1) THEN 1 WHEN SPLIT_PART('a,b,c', ',', 2) THEN 2
  WHEN SPLIT_PART('a,b,c', ',', 3) THEN 3 ELSE 0 END;
-- COL1: 2

-- # INSERT
-- # INSERT('Quadratic', 3, 4, 'What')
VALUES OVERLAY('Quadratic' PLACING 'What' FROM 3 FOR 4);
-- COL1: QuWhattic

-- # INSTR
-- # INSTR('foobarbar', 'bar')
VALUES POSITION('bar' IN 'foobarbar');
-- COL1: 4

-- # LCASE
-- # LCASE('MySQL')
VALUES LOWER('MySQL');
-- COL1: mysql

-- # LEFT
-- # LEFT('foobarbar', 5)
VALUES SUBSTRING('foobarbar' FROM 1 FOR 5);
-- COL1: fooba

-- # LENGTH
-- # LENGTH('héllo')
VALUES OCTET_LENGTH('héllo');
-- COL1: 6

-- # LOCATE
-- # LOCATE('bar', 'foobarbar')
VALUES POSITION('bar' IN 'foobarbar');
-- COL1: 4

-- # LOCATE
-- # LOCATE('bar', 'foobarbar', 5)
VALUES CASE POSITION('bar' IN SUBSTRING('foobarbar' FROM 5)) WHEN 0 THEN 0
  ELSE POSITION('bar' IN SUBSTRING('foobarbar' FROM 5)) + 5 - 1 END;
-- COL1: 7

-- # LOWER
-- # LOWER('QUADRATICALLY')
VALUES LOWER('QUADRATICALLY');
-- COL1: quadratically

-- # LPAD
-- # LPAD('hi', 4, '??')
VALUES LPAD('hi', 4, '??');
-- COL1: ??hi

-- # LTRIM
-- # LTRIM('  barbar')
VALUES LTRIM('  barbar');
-- COL1: barbar

-- # MID
-- # MID('Quadratically', 5, 6)
VALUES SUBSTRING('Quadratically' FROM 5 FOR 6);
-- COL1: ratica

-- # OCTET_LENGTH
-- # OCTET_LENGTH('héllo')
VALUES OCTET_LENGTH('héllo');
-- COL1: 6

-- # ORD
-- # ORD('2')
VALUES UNICODE('2');
-- COL1: 50

-- # POSITION
-- # POSITION('bar' IN 'foobarbar')
VALUES POSITION('bar' IN 'foobarbar');
-- COL1: 4

-- # QUOTE
-- # QUOTE('Don''t!')
VALUES '''' || REPLACE('Don''t!', '''', '\''') || '''';
-- COL1: 'Don\'t!'

-- # REGEXP_LIKE
-- # REGEXP_LIKE('abc', 'b')
VALUES 'abc' SIMILAR TO '%b%';
-- COL1: TRUE

-- # REGEXP_SUBSTR
-- # REGEXP_SUBSTR('abc123def', '[0-9]+')
VALUES SUBSTRING('abc123def' SIMILAR '%#"[0-9]+#"%' ESCAPE '#');
-- COL1: 123

-- # REPEAT
-- # REPEAT('MySQL', 3)
VALUES REPEAT('MySQL', 3);
-- COL1: MySQLMySQLMySQL

-- # REPLACE
-- # REPLACE('www.mysql.com', 'w', 'Ww')
VALUES REPLACE('www.mysql.com', 'w', 'Ww');
-- COL1: WwWwWw.mysql.com

-- # REVERSE
-- # REVERSE('abc')
VALUES REVERSE('abc');
-- COL1: cba

-- # RIGHT
-- # RIGHT('foobarbar', 4)
VALUES SUBSTRING('foobarbar' FROM CHAR_LENGTH('foobarbar') - 4 + 1);
-- COL1: rbar

-- # RPAD
-- # RPAD('hi', 5, '?')
VALUES RPAD('hi', 5, '?');
-- COL1: hi???

-- # RTRIM
-- # CONCAT(RTRIM('barbar   '), '|')
VALUES RTRIM('barbar   ') || '|';
-- COL1: barbar|

-- # SPACE
-- # CONCAT('[', SPACE(3), ']')
VALUES '[' || REPEAT(' ', 3) || ']';
-- COL1: [   ]

-- # STRCMP
-- # STRCMP('text', 'text2')
VALUES CASE WHEN 'text' < 'text2' THEN -1 WHEN 'text' > 'text2' THEN 1 ELSE 0 END;
-- COL1: -1

-- # SUBSTR
-- # SUBSTR('Quadratically', 5)
VALUES SUBSTRING('Quadratically' FROM 5);
-- COL1: ratically

-- # SUBSTR
-- # SUBSTR('Quadratically', 5, 6)
VALUES SUBSTRING('Quadratically' FROM 5 FOR 6);
-- COL1: ratica

-- # SUBSTRING
-- # SUBSTRING('Quadratically', 5)
VALUES SUBSTRING('Quadratically' FROM 5);
-- COL1: ratically

-- # SUBSTRING
-- # SUBSTRING('Quadratically', 5, 6)
VALUES SUBSTRING('Quadratically' FROM 5 FOR 6);
-- COL1: ratica

-- # SUBSTRING
-- # SUBSTRING('Sakila', -3)
VALUES SUBSTRING('Sakila' FROM CHAR_LENGTH('Sakila') - 3 + 1);
-- COL1: ila

-- # SUBSTRING_INDEX
-- # SUBSTRING_INDEX('www.mysql.com', '.', 1)
VALUES SPLIT_PART('www.mysql.com', '.', 1);
-- COL1: www

-- # SUBSTRING_INDEX
-- # SUBSTRING_INDEX('www.mysql.com', '.', -1)
VALUES SPLIT_PART('www.mysql.com', '.', -1);
-- COL1: com

-- # SUBSTRING_INDEX
-- # SUBSTRING_INDEX('www.mysql.com', '.', 2)
VALUES SPLIT_PART('www.mysql.com', '.', 1) || '.' || SPLIT_PART('www.mysql.com', '.', 2);
-- COL1: www.mysql

-- # TRIM
-- # CONCAT('|', TRIM('  bar   '), '|')
VALUES '|' || TRIM('  bar   ') || '|';
-- COL1: |bar|

-- # TRIM
-- # TRIM(LEADING 'x' FROM 'xxxbarxxx')
VALUES TRIM(LEADING 'x' FROM 'xxxbarxxx');
-- COL1: barxxx

-- # UCASE
-- # UCASE('Hej')
VALUES UPPER('Hej');
-- COL1: HEJ

-- # UPPER
-- # UPPER('Hej')
VALUES UPPER('Hej');
-- COL1: HEJ

-- # CAST
-- # CAST('12' AS SIGNED)
VALUES CAST('12' AS BIGINT);
-- COL1: 12

-- # CONVERT
-- # CONVERT('2024-03-15', DATE)
VALUES CAST('2024-03-15' AS DATE);
-- COL1: 2024-03-15

-- # DATABASE
-- # DATABASE()
VALUES CURRENT_SCHEMA;
-- COL1: PUBLIC

-- # SCHEMA
-- # SCHEMA()
VALUES CURRENT_SCHEMA;
-- COL1: PUBLIC

-- # AVG
-- # SELECT AVG(price) FROM products
SELECT AVG(price) FROM products;
-- COL1: 2.1875000000000000

-- # COUNT
-- # SELECT COUNT(*) FROM products
SELECT COUNT(*) FROM products;
-- COL1: 4

-- # COUNT
-- # SELECT COUNT(DISTINCT price > 2) FROM products
SELECT COUNT(DISTINCT price > 2) FROM products;
-- COL1: 2

-- # GROUP_CONCAT
-- # SELECT GROUP_CONCAT(name ORDER BY name SEPARATOR ', ') FROM products
SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY name) FROM products;
-- COL1: Apple, Banana, Cherry, Date

-- # MAX
-- # SELECT MAX(price) FROM products
SELECT MAX(price) FROM products;
-- COL1: 4.00

-- # MIN
-- # SELECT MIN(name) FROM products
SELECT MIN(name) FROM products;
-- COL1: Apple

-- # STD
-- # SELECT STD(price) FROM products
SELECT STDDEV_POP(price) FROM products;
-- COL1: 1.429324578254e0

-- # STDDEV
-- # SELECT STDDEV(price) FROM products
SELECT STDDEV_POP(price) FROM products;
-- COL1: 1.429324578254e0

-- # STDDEV_POP
-- # SELECT STDDEV_POP(price) FROM products
SELECT STDDEV_POP(price) FROM products;
-- COL1: 1.429324578254e0

-- # STDDEV_SAMP
-- # SELECT STDDEV_SAMP(price) FROM products
SELECT STDDEV_SAMP(price) FROM products;
-- COL1: 1.650441860028e0

-- # SUM
-- # SELECT SUM(price) FROM products
SELECT SUM(price) FROM products;
-- COL1: 8.75

-- # VARIANCE
-- # SELECT VARIANCE(price) FROM products
SELECT VAR_POP(price) FROM products;
-- COL1: 2.04296875e0

-- # VAR_POP
-- # SELECT VAR_POP(price) FROM products
SELECT VAR_POP(price) FROM products;
-- COL1: 2.04296875e0

-- # VAR_SAMP
-- # SELECT VAR_SAMP(price) FROM products
SELECT VAR_SAMP(price) FROM products;
-- COL1: 2.723958333333e0

-- # CUME_DIST
-- # SELECT name, CUME_DIST() OVER (ORDER BY price) AS cd FROM products ORDER BY price
SELECT name, CAST((SELECT COUNT(*) FROM products AS p2 WHERE p2.price <= p.price) AS DOUBLE PRECISION)
  / (SELECT COUNT(*) FROM products) AS cd
FROM products AS p ORDER BY price;
-- NAME: Banana CD: 0.25e0
-- NAME: Apple CD: 0.5e0
-- NAME: Date CD: 0.75e0
-- NAME: Cherry CD: 1e0

-- # DENSE_RANK
-- # SELECT name, DENSE_RANK() OVER (ORDER BY price) AS r FROM products ORDER BY price
SELECT name, (SELECT COUNT(DISTINCT p2.price) FROM products AS p2 WHERE p2.price < p.price) + 1 AS r
FROM products AS p ORDER BY price;
-- NAME: Banana R: 1
-- NAME: Apple R: 2
-- NAME: Date R: 3
-- NAME: Cherry R: 4

-- # FIRST_VALUE
-- # SELECT name, FIRST_VALUE(name) OVER (ORDER BY price) AS f FROM products ORDER BY price
SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS f
FROM products AS p ORDER BY price;
-- NAME: Banana F: Banana
-- NAME: Apple F: Banana
-- NAME: Date F: Banana
-- NAME: Cherry F: Banana

-- # LAG
-- # SELECT name, LAG(name) OVER (ORDER BY price) AS prev FROM products ORDER BY price
SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price < p.price
  ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS prev
FROM products AS p ORDER BY price;
-- NAME: Banana PREV: NULL
-- NAME: Apple PREV: Banana
-- NAME: Date PREV: Apple
-- NAME: Cherry PREV: Date

-- # LAST_VALUE
-- # SELECT name, LAST_VALUE(name) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS l FROM products ORDER BY price
SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS l
FROM products AS p ORDER BY price;
-- NAME: Banana L: Cherry
-- NAME: Apple L: Cherry
-- NAME: Date L: Cherry
-- NAME: Cherry L: Cherry

-- # LEAD
-- # SELECT name, LEAD(name) OVER (ORDER BY price) AS next FROM products ORDER BY price
SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price > p.price
  ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS next
FROM products AS p ORDER BY price;
-- NAME: Banana NEXT: Apple
-- NAME: Apple NEXT: Date
-- NAME: Date NEXT: Cherry
-- NAME: Cherry NEXT: NULL

-- # NTH_VALUE
-- # SELECT name, NTH_VALUE(name, 2) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS n FROM products ORDER BY price
SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price OFFSET 1 ROW FETCH FIRST 1 ROW ONLY) AS n
FROM products AS p ORDER BY price;
-- NAME: Banana N: Apple
-- NAME: Apple N: Apple
-- NAME: Date N: Apple
-- NAME: Cherry N: Apple

-- # PERCENT_RANK
-- # SELECT name, PERCENT_RANK() OVER (ORDER BY price) AS pr FROM products ORDER BY price
SELECT name, CAST((SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) AS DOUBLE PRECISION)
  / ((SELECT COUNT(*) FROM products) - 1) AS pr
FROM products AS p ORDER BY price;
-- NAME: Banana PR: 0e0
-- NAME: Apple PR: 0.333333333333e0
-- NAME: Date PR: 0.666666666667e0
-- NAME: Cherry PR: 1e0

-- # RANK
-- # SELECT name, RANK() OVER (ORDER BY price) AS r FROM products ORDER BY price
SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) + 1 AS r
FROM products AS p ORDER BY price;
-- NAME: Banana R: 1
-- NAME: Apple R: 2
-- NAME: Date R: 3
-- NAME: Cherry R: 4

-- # ROW_NUMBER
-- # SELECT name, ROW_NUMBER() OVER (ORDER BY price) AS rn FROM products ORDER BY price
SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) + 1 AS rn
FROM products AS p ORDER BY price;
-- NAME: Banana RN: 1
-- NAME: Apple RN: 2
-- NAME: Date RN: 3
-- NAME: Cherry RN: 4

-- # ANY_VALUE
-- # SELECT ANY_VALUE(name) FROM products WHERE sku = 'A1'
SELECT ANY_VALUE(name) FROM products WHERE sku = 'A1';
-- COL1: Apple

-- # NAME_CONST
-- # SELECT NAME_CONST('myname', 14)
SELECT 14 AS myname FROM (VALUES 1) AS t (x);
-- MYNAME: 14
