-- # The examples of docs/compatibility-sqlite3.rst, one test per
-- # example. Each example runs with the example table of the page.

/* setup */
CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);

-- # abs
-- # SELECT abs(-2.5);
VALUES ABS(-2.5);
-- COL1: 2.5

-- # char
-- # SELECT char(72, 105);
VALUES CHR(72) || CHR(105);
-- COL1: Hi

-- # coalesce
-- # SELECT coalesce(qty, 0) FROM products WHERE sku = 'D4';
SELECT COALESCE(qty, 0) FROM products WHERE sku = 'D4';
-- COL1: 0

-- # concat
-- # SELECT concat(sku, ':', name) FROM products WHERE sku = 'A1';
SELECT COALESCE(sku, '') || ':' || COALESCE(name, '') FROM products WHERE sku = 'A1';
-- COL1: A1:Apple

-- # concat_ws
-- # SELECT concat_ws('-', 'A1', 'Apple');
VALUES 'A1' || '-' || 'Apple';
-- COL1: A1-Apple

-- # format
-- # SELECT format('%s costs %.2f', 'Cherry', 4);
VALUES 'Cherry' || ' costs ' || CAST(4.00 AS VARCHAR(12));
-- COL1: Cherry costs 4.00

-- # glob
-- # SELECT glob('Ch*', 'Cherry');
VALUES 'Cherry' LIKE 'Ch%';
-- COL1: TRUE

-- # if
-- # SELECT if(10 > 20, 'many', 'few');
VALUES CASE WHEN 10 > 20 THEN 'many' ELSE 'few' END;
-- COL1: few

-- # ifnull
-- # SELECT ifnull(qty, -1) FROM products WHERE sku = 'D4';
SELECT COALESCE(qty, -1) FROM products WHERE sku = 'D4';
-- COL1: -1

-- # iif
-- # SELECT iif(4 < 1, 'cheap', 4 < 3.5, 'fair', 'dear');
VALUES CASE WHEN 4 < 1 THEN 'cheap' WHEN 4 < 3.5 THEN 'fair' ELSE 'dear' END;
-- COL1: dear

-- # instr
-- # SELECT instr('Banana', 'na');
VALUES POSITION('na' IN 'Banana');
-- COL1: 3

-- # length
-- # SELECT length('Cherry');
VALUES CHAR_LENGTH('Cherry');
-- COL1: 6

-- # like
-- # SELECT like('%AN%', name) FROM products WHERE sku = 'B2';
SELECT UPPER(name) LIKE UPPER('%AN%') FROM products WHERE sku = 'B2';
-- COL1: TRUE

-- # like
-- # SELECT like('10!%', '10%', '!');
VALUES '10%' LIKE '10!%' ESCAPE '!';
-- COL1: TRUE

-- # likelihood
-- # SELECT name FROM products WHERE likelihood(price > 3.5, 0.25);
SELECT name FROM products WHERE price > 3.5;
-- NAME: Cherry

-- # likely
-- # SELECT name FROM products WHERE likely(qty > 20);
SELECT name FROM products WHERE qty > 20;
-- NAME: Banana

-- # lower
-- # SELECT lower('Apple');
VALUES LOWER('Apple');
-- COL1: apple

-- # ltrim
-- # SELECT ltrim('  Apple');
VALUES LTRIM('  Apple');
-- COL1: Apple

-- # ltrim
-- # SELECT ltrim('xxAxx', 'x');
VALUES LTRIM('xxAxx', 'x');
-- COL1: Axx

-- # max
-- # SELECT max(3, 7, 5);
VALUES GREATEST(3, 7, 5);
-- COL1: 7

-- # max
-- # SELECT max(price) FROM products;
SELECT MAX(price) FROM products;
-- COL1: 4.00

-- # min
-- # SELECT min(3, 7, 5);
VALUES LEAST(3, 7, 5);
-- COL1: 3

-- # min
-- # SELECT min(qty) FROM products;
SELECT MIN(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 5

-- # nullif
-- # SELECT nullif(qty, 10) FROM products WHERE sku = 'A1';
SELECT NULLIF(qty, 10) FROM products WHERE sku = 'A1';
-- COL1: NULL

-- # octet_length
-- # SELECT octet_length('café');
VALUES OCTET_LENGTH('café');
-- COL1: 5

-- # printf
-- # SELECT printf('%d left', 10);
VALUES CAST(10 AS VARCHAR(11)) || ' left';
-- COL1: 10 left

-- # quote
-- # SELECT quote('It''s');
VALUES '''' || REPLACE('It''s', '''', '''''') || '''';
-- COL1: 'It''s'

-- # random
-- # SELECT abs(random() % 6) + 1 BETWEEN 1 AND 6;
VALUES FLOOR(RANDOM() * 6) + 1 BETWEEN 1 AND 6;
-- COL1: TRUE

-- # replace
-- # SELECT replace('Banana', 'an', 'AN');
VALUES REPLACE('Banana', 'an', 'AN');
-- COL1: BANANa

-- # round
-- # SELECT round(2.5);
VALUES ROUND(2.5);
-- COL1: 3

-- # round
-- # SELECT round(price * 1.1, 2) FROM products WHERE sku = 'A1';
SELECT ROUND(price * 1.1, 2) FROM products WHERE sku = 'A1';
-- COL1: 1.65

-- # rtrim
-- # SELECT rtrim('Apple  ') || '|';
VALUES RTRIM('Apple  ') || '|';
-- COL1: Apple|

-- # rtrim
-- # SELECT rtrim('xxAxx', 'x');
VALUES RTRIM('xxAxx', 'x');
-- COL1: xxA

-- # sign
-- # SELECT sign(-7.5);
VALUES SIGN(-7.5);
-- COL1: -1

-- # substr
-- # SELECT substr('Cherry', 2, 3);
VALUES SUBSTRING('Cherry' FROM 2 FOR 3);
-- COL1: her

-- # substr
-- # SELECT substr('Cherry', 3);
VALUES SUBSTRING('Cherry' FROM 3);
-- COL1: erry

-- # substring
-- # SELECT substring('Banana', 3, 2);
VALUES SUBSTRING('Banana' FROM 3 FOR 2);
-- COL1: na

-- # substring
-- # SELECT substring('Banana', 3);
VALUES SUBSTRING('Banana' FROM 3);
-- COL1: nana

-- # trim
-- # SELECT '|' || trim('  Apple  ') || '|';
VALUES '|' || TRIM('  Apple  ') || '|';
-- COL1: |Apple|

-- # trim
-- # SELECT trim('xxAxx', 'x');
VALUES BTRIM('xxAxx', 'x');
-- COL1: A

-- # unicode
-- # SELECT unicode('A');
VALUES UNICODE('A');
-- COL1: 65

-- # unistr
-- # SELECT unistr('caf\u00e9');
VALUES 'caf' || CHR(233);
-- COL1: café

-- # unlikely
-- # SELECT name FROM products WHERE unlikely(qty IS NULL);
SELECT name FROM products WHERE qty IS NULL;
-- NAME: Date

-- # upper
-- # SELECT upper('Apple');
VALUES UPPER('Apple');
-- COL1: APPLE

-- # date
-- # SELECT date('2024-03-05 14:30:15');
VALUES CAST(TIMESTAMP '2024-03-05 14:30:15' AS DATE);
-- COL1: 2024-03-05

-- # date
-- # SELECT date('now') > '2020-01-01';
VALUES CURRENT_DATE > DATE '2020-01-01';
-- COL1: TRUE

-- # date
-- # SELECT date('2024-03-05 14:30:15', 'start of month');
VALUES MAKE_DATE(EXTRACT(YEAR FROM TIMESTAMP '2024-03-05 14:30:15'), EXTRACT(MONTH FROM TIMESTAMP '2024-03-05 14:30:15'), 1);
-- COL1: 2024-03-01

-- # datetime
-- # SELECT datetime('2024-03-05 14:30:15.250');
VALUES CAST(TIMESTAMP '2024-03-05 14:30:15.25' AS TIMESTAMP(0));
-- COL1: 2024-03-05T14:30:15

-- # datetime
-- # SELECT datetime('now') > '2020-01-01 00:00:00';
VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # julianday
/* extensions V402-08 */
-- # SELECT julianday('2024-03-05 14:30:15');
VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 14:30:15') / 86400.00000000 + 2440587.5;
-- COL1: 2460375.10434027

-- # strftime
-- # SELECT strftime('%Y', '2024-03-05');
VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
-- COL1: 2024

-- # strftime
/* extensions V402-04 */
-- # SELECT strftime('%j', '2024-03-05');
VALUES EXTRACT(DOY FROM DATE '2024-03-05');
-- COL1: 65

-- # strftime
/* extensions V402-02 */
-- # SELECT strftime('%w', '2024-03-05');
VALUES EXTRACT(DOW FROM DATE '2024-03-05');
-- COL1: 2

-- # strftime
-- # SELECT strftime('%H:%M', '14:30:15');
VALUES SUBSTRING(CAST(TIME '14:30:15' AS VARCHAR(15)) FROM 7 FOR 5);
-- COL1: 14:30

-- # time
-- # SELECT time('2024-03-05 14:30:15');
VALUES CAST(TIMESTAMP '2024-03-05 14:30:15' AS TIME);
-- COL1: 14:30:15

-- # time
-- # SELECT time('now') >= '00:00:00';
VALUES LOCALTIME >= TIME '00:00:00';
-- COL1: TRUE

-- # unixepoch
/* extensions V402-08 */
-- # SELECT unixepoch('2024-03-05 14:30:15');
VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 14:30:15');
-- COL1: 1709649015

-- # avg
-- # SELECT avg(price) FROM products;
SELECT AVG(CAST(price AS DOUBLE PRECISION)) FROM products;
-- COL1: 2.1875e0

-- # count
-- # SELECT count(qty) FROM products;
SELECT COUNT(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 3

-- # count
-- # SELECT count(*) FROM products;
SELECT COUNT(*) FROM products;
-- COL1: 4

-- # group_concat
-- # SELECT group_concat(name ORDER BY name) FROM products;
SELECT LISTAGG(name, ',') WITHIN GROUP (ORDER BY name) FROM products;
-- COL1: Apple,Banana,Cherry,Date

-- # group_concat
-- # SELECT group_concat(sku, '; ' ORDER BY price DESC) FROM products;
SELECT LISTAGG(sku, '; ') WITHIN GROUP (ORDER BY price DESC) FROM products;
-- COL1: C3; D4; A1; B2

-- # median
-- # SELECT median(price) FROM products;
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(price AS DOUBLE PRECISION)) FROM products;
-- COL1: 2.25e0

-- # percentile
-- # SELECT percentile(price, 25) FROM products;
SELECT PERCENTILE_CONT(25 / 100e0) WITHIN GROUP (ORDER BY CAST(price AS DOUBLE PRECISION)) FROM products;
-- COL1: 1.1875e0

-- # percentile_cont
-- # SELECT percentile_cont(price, 0.75) FROM products;
SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CAST(price AS DOUBLE PRECISION)) FROM products;
-- COL1: 3.25e0

-- # percentile_disc
-- # SELECT percentile_disc(price, 0.5) FROM products;
SELECT PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 1.5e0

-- # string_agg
-- # SELECT string_agg(name, ' / ' ORDER BY qty) FROM products;
SELECT LISTAGG(name, ' / ') WITHIN GROUP (ORDER BY qty) FROM products;
-- COL1: Date / Cherry / Apple / Banana

-- # sum
-- # SELECT sum(qty) FROM products;
SELECT SUM(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 55

-- # total
-- # SELECT total(qty) FROM products WHERE qty > 100;
SELECT COALESCE(SUM(CAST(qty AS DOUBLE PRECISION)), 0e0) FROM products WHERE qty > 100;
-- COL1: 0e0

-- # cume_dist
-- # SELECT name, cume_dist() OVER (ORDER BY price) AS cd FROM products ORDER BY price;
SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price <= p.price)
  / CAST((SELECT COUNT(*) FROM products) AS DOUBLE PRECISION) AS cd
FROM products AS p ORDER BY price;
-- NAME: Banana CD: 0.25e0
-- NAME: Apple CD: 0.5e0
-- NAME: Date CD: 0.75e0
-- NAME: Cherry CD: 1e0

-- # dense_rank
-- # SELECT name, dense_rank() OVER (ORDER BY price) AS r FROM products ORDER BY price;
SELECT name, (SELECT COUNT(DISTINCT p2.price) FROM products AS p2 WHERE p2.price <= p.price) AS r
FROM products AS p ORDER BY price;
-- NAME: Banana R: 1
-- NAME: Apple R: 2
-- NAME: Date R: 3
-- NAME: Cherry R: 4

-- # first_value
-- # SELECT name, first_value(name) OVER (ORDER BY price) AS f FROM products ORDER BY price;
SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS f
FROM products AS p ORDER BY price;
-- NAME: Banana F: Banana
-- NAME: Apple F: Banana
-- NAME: Date F: Banana
-- NAME: Cherry F: Banana

-- # lag
-- # SELECT name, lag(name) OVER (ORDER BY price) AS prev FROM products ORDER BY price;
SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price < p.price
  ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS prev
FROM products AS p ORDER BY price;
-- NAME: Banana PREV: NULL
-- NAME: Apple PREV: Banana
-- NAME: Date PREV: Apple
-- NAME: Cherry PREV: Date

-- # last_value
-- # SELECT name, last_value(name) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS l FROM products ORDER BY price;
SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS l
FROM products AS p ORDER BY price;
-- NAME: Banana L: Cherry
-- NAME: Apple L: Cherry
-- NAME: Date L: Cherry
-- NAME: Cherry L: Cherry

-- # lead
-- # SELECT name, lead(name) OVER (ORDER BY price) AS next FROM products ORDER BY price;
SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price > p.price
  ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS next
FROM products AS p ORDER BY price;
-- NAME: Banana NEXT: Apple
-- NAME: Apple NEXT: Date
-- NAME: Date NEXT: Cherry
-- NAME: Cherry NEXT: NULL

-- # nth_value
-- # SELECT name, nth_value(name, 2) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS n FROM products ORDER BY price;
SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price OFFSET 1 ROW FETCH FIRST 1 ROW ONLY) AS n
FROM products AS p ORDER BY price;
-- NAME: Banana N: Apple
-- NAME: Apple N: Apple
-- NAME: Date N: Apple
-- NAME: Cherry N: Apple

-- # ntile
-- # SELECT name, ntile(2) OVER (ORDER BY price) AS g FROM products ORDER BY price;
SELECT name, ((SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) * 2
  / (SELECT COUNT(*) FROM products)) + 1 AS g
FROM products AS p ORDER BY price;
-- NAME: Banana G: 1
-- NAME: Apple G: 1
-- NAME: Date G: 2
-- NAME: Cherry G: 2

-- # percent_rank
-- # SELECT name, percent_rank() OVER (ORDER BY price) AS pr FROM products ORDER BY price;
SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price)
  / CAST((SELECT COUNT(*) FROM products) - 1 AS DOUBLE PRECISION) AS pr
FROM products AS p ORDER BY price;
-- NAME: Banana PR: 0e0
-- NAME: Apple PR: 0.333333333333e0
-- NAME: Date PR: 0.666666666667e0
-- NAME: Cherry PR: 1e0

-- # rank
-- # SELECT name, rank() OVER (ORDER BY price DESC) AS r FROM products ORDER BY price DESC;
SELECT name, 1 + (SELECT COUNT(*) FROM products AS p2 WHERE p2.price > p.price) AS r
FROM products AS p ORDER BY price DESC;
-- NAME: Cherry R: 1
-- NAME: Date R: 2
-- NAME: Apple R: 3
-- NAME: Banana R: 4

-- # row_number
-- # SELECT name, row_number() OVER (ORDER BY price) AS rn FROM products ORDER BY price;
SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price <= p.price) AS rn
FROM products AS p ORDER BY price;
-- NAME: Banana RN: 1
-- NAME: Apple RN: 2
-- NAME: Date RN: 3
-- NAME: Cherry RN: 4

-- # acos
-- # SELECT acos(0.5);
VALUES ACOS(0.5);
-- COL1: 1.047197551197e0

-- # acosh
-- # SELECT acosh(2);
VALUES LN(2e0 + SQRT(2e0 * 2e0 - 1));
-- COL1: 1.316957896925e0

-- # asin
-- # SELECT asin(0.5);
VALUES ASIN(0.5);
-- COL1: 0.523598775598e0

-- # asinh
-- # SELECT asinh(1);
VALUES LN(1e0 + SQRT(1e0 * 1e0 + 1));
-- COL1: 0.88137358702e0

-- # atan
-- # SELECT atan(1);
VALUES ATAN(1);
-- COL1: 0.785398163397e0

-- # atan2
-- # SELECT atan2(1, 2);
VALUES ATAN2(1, 2);
-- COL1: 0.463647609001e0

-- # atanh
-- # SELECT atanh(0.5);
VALUES 0.5e0 * LN((1 + 0.5e0) / (1 - 0.5e0));
-- COL1: 0.549306144334e0

-- # ceil
-- # SELECT ceil(1.2);
VALUES CEIL(1.2);
-- COL1: 2

-- # ceiling
-- # SELECT ceiling(-1.2);
VALUES CEILING(-1.2);
-- COL1: -1

-- # cos
-- # SELECT cos(0);
VALUES COS(0);
-- COL1: 1e0

-- # cosh
-- # SELECT cosh(1);
VALUES COSH(1);
-- COL1: 1.543080634815e0

-- # degrees
-- # SELECT degrees(pi());
VALUES DEGREES(PI());
-- COL1: 180e0

-- # exp
-- # SELECT exp(1);
VALUES EXP(1);
-- COL1: 2.718281828459e0

-- # floor
-- # SELECT floor(-1.2);
VALUES FLOOR(-1.2);
-- COL1: -2

-- # ln
-- # SELECT ln(10);
VALUES LN(10);
-- COL1: 2.302585092994e0

-- # log
-- # SELECT log(1000);
VALUES LOG10(1000);
-- COL1: 3e0

-- # log
-- # SELECT log(2, 8);
VALUES LOG(2, 8);
-- COL1: 3e0

-- # log10
-- # SELECT log10(0.01);
VALUES LOG10(0.01);
-- COL1: -2e0

-- # log2
-- # SELECT log2(1024);
VALUES LOG(2, 1024);
-- COL1: 10e0

-- # mod
/* extensions V403-01 */
-- # SELECT mod(7.5, 2);
VALUES MOD(7.5, 2);
-- COL1: 1.5

-- # pi
-- # SELECT pi();
VALUES PI();
-- COL1: 3.14159265359e0

-- # pow
-- # SELECT pow(2, 10);
VALUES POWER(2, 10);
-- COL1: 1024e0

-- # power
-- # SELECT power(9, 0.5);
VALUES POWER(9, 0.5);
-- COL1: 3e0

-- # radians
-- # SELECT radians(180);
VALUES RADIANS(180);
-- COL1: 3.14159265359e0

-- # sin
-- # SELECT sin(pi() / 2);
VALUES SIN(PI() / 2);
-- COL1: 1e0

-- # sinh
-- # SELECT sinh(1);
VALUES SINH(1);
-- COL1: 1.175201193644e0

-- # sqrt
-- # SELECT sqrt(2);
VALUES SQRT(2);
-- COL1: 1.414213562373e0

-- # tan
-- # SELECT tan(pi() / 4);
VALUES TAN(PI() / 4);
-- COL1: 1e0

-- # tanh
-- # SELECT tanh(1);
VALUES TANH(1);
-- COL1: 0.761594155956e0

-- # trunc
-- # SELECT trunc(-2.7);
VALUES TRUNC(-2.7);
-- COL1: -2

-- # json_array
-- # SELECT json_array('A1', 10);
VALUES '["' || 'A1' || '",' || CAST(10 AS VARCHAR(11)) || ']';
-- COL1: ["A1",10]

-- # json_group_array
-- # SELECT json_group_array(name ORDER BY name) FROM products;
SELECT '[' || LISTAGG('"' || name || '"', ',') WITHIN GROUP (ORDER BY name) || ']' FROM products;
-- COL1: ["Apple","Banana","Cherry","Date"]

-- # json_group_object
-- # SELECT json_group_object(sku, price) FROM (SELECT * FROM products ORDER BY sku);
SELECT '{' || LISTAGG('"' || sku || '":' || CAST(price AS VARCHAR(12)), ',') WITHIN GROUP (ORDER BY sku) || '}'
FROM products;
-- COL1: {"A1":1.50,"B2":0.25,"C3":4.00,"D4":3.00}

-- # json_object
-- # SELECT json_object('sku', 'A1', 'qty', 10);
VALUES '{"sku":"' || 'A1' || '","qty":' || CAST(10 AS VARCHAR(11)) || '}';
-- COL1: {"sku":"A1","qty":10}

-- # json_quote
-- # SELECT json_quote('Banana');
VALUES '"' || 'Banana' || '"';
-- COL1: "Banana"
