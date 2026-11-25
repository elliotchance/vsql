-- # The examples of docs/compatibility-postgresql.rst, one test per function.
-- # Each example runs with the example tables of the page.

/* setup */
CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);
CREATE SEQUENCE ids;

-- # num_nonnulls
-- # num_nonnulls(1, NULL, 2)
VALUES (CASE WHEN 1 IS NULL THEN 0 ELSE 1 END) + (CASE WHEN CAST(NULL AS INTEGER) IS NULL THEN 0 ELSE 1 END) + (CASE WHEN 2 IS NULL THEN 0 ELSE 1 END);
-- COL1: 2

-- # num_nulls
-- # num_nulls(1, NULL, 2)
VALUES (CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) + (CASE WHEN CAST(NULL AS INTEGER) IS NULL THEN 1 ELSE 0 END) + (CASE WHEN 2 IS NULL THEN 1 ELSE 0 END);
-- COL1: 1

-- # abs
-- # abs(-17.4)
VALUES ABS(-17.4);
-- COL1: 17.4

-- # acos
-- # acos(1)
VALUES ACOS(1e0);
-- COL1: 0e0

-- # acosd
-- # acosd(0.5)
VALUES DEGREES(ACOS(0.5e0));
-- COL1: 60e0

-- # acosh
-- # acosh(2)
VALUES LN(2e0 + SQRT(2e0 * 2e0 - 1));
-- COL1: 1.316957896925e0

-- # asin
-- # asin(1)
VALUES ASIN(1e0);
-- COL1: 1.570796326795e0

-- # asind
-- # asind(0.5)
VALUES DEGREES(ASIN(0.5e0));
-- COL1: 30e0

-- # asinh
-- # asinh(1)
VALUES LN(1e0 + SQRT(1e0 * 1e0 + 1));
-- COL1: 0.88137358702e0

-- # atan
-- # atan(1)
VALUES ATAN(1e0);
-- COL1: 0.785398163397e0

-- # atan2
-- # atan2(1, 0)
VALUES ATAN2(1e0, 0e0);
-- COL1: 1.570796326795e0

-- # atan2d
-- # atan2d(1, 0)
VALUES DEGREES(ATAN2(1e0, 0e0));
-- COL1: 90e0

-- # atand
-- # atand(1)
VALUES DEGREES(ATAN(1e0));
-- COL1: 45e0

-- # atanh
-- # atanh(0.5)
VALUES LN((1 + 0.5e0) / (1 - 0.5e0)) / 2;
-- COL1: 0.549306144334e0

-- # cbrt
-- # cbrt(64)
VALUES CBRT(64e0);
-- COL1: 4e0

-- # ceil
-- # ceil(-42.8)
VALUES CEIL(-42.8);
-- COL1: -42

-- # ceiling
-- # ceiling(95.3)
VALUES CEILING(95.3);
-- COL1: 96

-- # cos
-- # cos(0)
VALUES COS(0e0);
-- COL1: 1e0

-- # cosd
-- # cosd(60)
VALUES COS(RADIANS(60e0));
-- COL1: 0.5e0

-- # cosh
-- # cosh(0)
VALUES COSH(0e0);
-- COL1: 1e0

-- # cot
-- # cot(0.5)
VALUES 1 / TAN(0.5e0);
-- COL1: 1.830487721712e0

-- # cotd
-- # cotd(45)
VALUES 1 / TAN(RADIANS(45e0));
-- COL1: 1e0

-- # degrees
-- # degrees(0.5)
VALUES DEGREES(0.5e0);
-- COL1: 28.647889756541e0

-- # div
-- # div(9, 4)
VALUES TRUNC(9 / 4.0);
-- COL1: 2

-- # erf
-- # erf(1.0)
VALUES ERF(1e0);
-- COL1: 0.84270079295e0

-- # erfc
-- # erfc(1.0)
VALUES ERFC(1e0);
-- COL1: 0.15729920705e0

-- # exp
-- # exp(1.0)
VALUES EXP(1e0);
-- COL1: 2.718281828459e0

-- # factorial
-- # factorial(5)
VALUES FACTORIAL(5);
-- COL1: 120

-- # floor
-- # floor(-42.8)
VALUES FLOOR(-42.8);
-- COL1: -43

-- # gamma
-- # gamma(5)
VALUES GAMMA(5e0);
-- COL1: 24e0

-- # gcd
-- # gcd(1071, 462)
VALUES GCD(1071, 462);
-- COL1: 21

-- # lcm
-- # lcm(4, 6)
VALUES LCM(4, 6);
-- COL1: 12

-- # lgamma
-- # lgamma(1000)
VALUES LGAMMA(1000e0);
-- COL1: 5905.220423209182e0

-- # ln
-- # ln(2.0)
VALUES LN(2e0);
-- COL1: 0.69314718056e0

-- # log
-- # log(100)
VALUES LOG10(100e0);
-- COL1: 2e0

-- # log
-- # log(2.0, 64.0)
VALUES LOG(2e0, 64e0);
-- COL1: 6e0

-- # log10
-- # log10(1000)
VALUES LOG10(1000e0);
-- COL1: 3e0

-- # min_scale
-- # min_scale(8.4100)
VALUES MIN_SCALE(8.4100);
-- COL1: 2

-- # mod
-- # mod(9, 4)
VALUES MOD(9, 4);
-- COL1: 1

-- # pi
-- # pi()
VALUES PI();
-- COL1: 3.14159265359e0

-- # power
-- # power(9, 3)
VALUES POWER(9, 3);
-- COL1: 729e0

-- # radians
-- # radians(45.0)
VALUES RADIANS(45e0);
-- COL1: 0.785398163397e0

-- # random
-- # random() < 1
VALUES RANDOM() < 1;
-- COL1: TRUE

-- # random
-- # random(1, 10) BETWEEN 1 AND 10
VALUES 1 + FLOOR(RANDOM() * (10 - 1 + 1)) BETWEEN 1 AND 10;
-- COL1: TRUE

-- # round
-- # round(42.4)
VALUES ROUND(42.4);
-- COL1: 42

-- # round
-- # round(42.4382, 2)
VALUES ROUND(42.4382, 2);
-- COL1: 42.44

-- # sign
-- # sign(-8.4)
VALUES SIGN(-8.4);
-- COL1: -1

-- # sin
-- # sin(1)
VALUES SIN(1e0);
-- COL1: 0.841470984808e0

-- # sind
-- # sind(30)
VALUES SIN(RADIANS(30e0));
-- COL1: 0.5e0

-- # sinh
-- # sinh(1)
VALUES SINH(1e0);
-- COL1: 1.175201193644e0

-- # sqrt
-- # sqrt(2)
VALUES SQRT(2e0);
-- COL1: 1.414213562373e0

-- # tan
-- # tan(1)
VALUES TAN(1e0);
-- COL1: 1.557407724655e0

-- # tand
-- # tand(45)
VALUES TAN(RADIANS(45e0));
-- COL1: 1e0

-- # tanh
-- # tanh(1)
VALUES TANH(1e0);
-- COL1: 0.761594155956e0

-- # trim_scale
-- # trim_scale(8.4100)
VALUES TRIM_SCALE(8.4100);
-- COL1: 8.41

-- # trunc
-- # trunc(42.8)
VALUES TRUNC(42.8);
-- COL1: 42

-- # trunc
-- # trunc(42.4382, 2)
VALUES TRUNC(42.4382, 2);
-- COL1: 42.43

-- # width_bucket
-- # width_bucket(5.35, 0.024, 10.06, 5)
VALUES WIDTH_BUCKET(5.35, 0.024, 10.06, 5);
-- COL1: 3

-- # ascii
-- # ascii('x')
VALUES UNICODE('x');
-- COL1: 120

-- # bit_length
-- # bit_length('jose')
VALUES OCTET_LENGTH('jose') * 8;
-- COL1: 32

-- # btrim
-- # btrim('xyxtrimyyx', 'xy')
VALUES BTRIM('xyxtrimyyx', 'xy');
-- COL1: trim

-- # casefold
-- # casefold('HELLO')
VALUES LOWER('HELLO');
-- COL1: hello

-- # char_length
-- # char_length('josé')
VALUES CHAR_LENGTH('josé');
-- COL1: 4

-- # character_length
-- # character_length('josé')
VALUES CHARACTER_LENGTH('josé');
-- COL1: 4

-- # chr
-- # chr(65)
VALUES CHR(65);
-- COL1: A

-- # concat
-- # concat('abcde', NULL, 'xy')
VALUES CONCAT('abcde', CAST(NULL AS VARCHAR(10)), 'xy');
-- COL1: abcdexy

-- # concat_ws
-- # concat_ws(',', 'abcde', 'xy')
VALUES CONCAT_WS(',', 'abcde', 'xy');
-- COL1: abcde,xy

-- # format
-- # format('Hello %s!', 'World')
VALUES 'Hello ' || 'World' || '!';
-- COL1: Hello World!

-- # initcap
-- # initcap('hi THOMAS')
VALUES INITCAP('hi THOMAS');
-- COL1: Hi Thomas

-- # left
-- # left('abcde', 2)
VALUES SUBSTRING('abcde' FROM 1 FOR 2);
-- COL1: ab

-- # length
-- # length('jose')
VALUES LENGTH('jose');
-- COL1: 4

-- # lower
-- # lower('TOM')
VALUES LOWER('TOM');
-- COL1: tom

-- # lpad
-- # lpad('hi', 5, 'xy')
VALUES LPAD('hi', 5, 'xy');
-- COL1: xyxhi

-- # ltrim
-- # ltrim('zzzytest', 'xyz')
VALUES LTRIM('zzzytest', 'xyz');
-- COL1: test

-- # octet_length
-- # octet_length('josé')
VALUES OCTET_LENGTH('josé');
-- COL1: 5

-- # overlay
-- # overlay('Txxxxas' placing 'hom' from 2 for 4)
VALUES OVERLAY('Txxxxas' PLACING 'hom' FROM 2 FOR 4);
-- COL1: Thomas

-- # position
-- # position('om' in 'Thomas')
VALUES POSITION('om' IN 'Thomas');
-- COL1: 3

-- # quote_ident
-- # quote_ident('Foo bar')
VALUES '"' || REPLACE('Foo bar', '"', '""') || '"';
-- COL1: "Foo bar"

-- # quote_literal
-- # quote_literal('O''Reilly')
VALUES '''' || REPLACE('O''Reilly', '''', '''''') || '''';
-- COL1: 'O''Reilly'

-- # quote_nullable
-- # quote_nullable(NULL)
VALUES COALESCE('''' || REPLACE(CAST(NULL AS VARCHAR(10)), '''', '''''') || '''', 'NULL');
-- COL1: NULL

-- # repeat
-- # repeat('Pg', 4)
VALUES REPEAT('Pg', 4);
-- COL1: PgPgPgPg

-- # replace
-- # replace('abcdefabcdef', 'cd', 'XX')
VALUES REPLACE('abcdefabcdef', 'cd', 'XX');
-- COL1: abXXefabXXef

-- # reverse
-- # reverse('abcde')
VALUES REVERSE('abcde');
-- COL1: edcba

-- # right
-- # right('abcde', 2)
VALUES SUBSTRING('abcde' FROM CHAR_LENGTH('abcde') - 2 + 1);
-- COL1: de

-- # rpad
-- # rpad('hi', 5, 'xy')
VALUES RPAD('hi', 5, 'xy');
-- COL1: hixyx

-- # rtrim
-- # rtrim('testxxzx', 'xyz')
VALUES RTRIM('testxxzx', 'xyz');
-- COL1: test

-- # split_part
-- # split_part('abc~@~def~@~ghi', '~@~', 2)
VALUES SPLIT_PART('abc~@~def~@~ghi', '~@~', 2);
-- COL1: def

-- # starts_with
-- # starts_with('alphabet', 'alph')
VALUES SUBSTRING('alphabet' FROM 1 FOR CHAR_LENGTH('alph')) = 'alph';
-- COL1: TRUE

-- # strpos
-- # strpos('high', 'ig')
VALUES POSITION('ig' IN 'high');
-- COL1: 2

-- # substr
-- # substr('alphabet', 3, 2)
VALUES SUBSTRING('alphabet' FROM 3 FOR 2);
-- COL1: ph

-- # substring
-- # substring('Thomas' from 2 for 3)
VALUES SUBSTRING('Thomas' FROM 2 FOR 3);
-- COL1: hom

-- # substring
-- # substring('Thomas' similar '%#"o_a#"_' escape '#')
VALUES SUBSTRING('Thomas' SIMILAR '%#"o_a#"_' ESCAPE '#');
-- COL1: oma

-- # translate
-- # translate('12345', '143', 'ax')
VALUES REPLACE(REPLACE(REPLACE('12345', '1', 'a'), '4', 'x'), '3', '');
-- COL1: a2x5

-- # trim
-- # trim(both 'x' from 'xTomxx')
VALUES TRIM(BOTH 'x' FROM 'xTomxx');
-- COL1: Tom

-- # trim
-- # trim(both 'xyz' from 'yxTomxx')
VALUES BTRIM('yxTomxx', 'xyz');
-- COL1: Tom

-- # upper
-- # upper('tom')
VALUES UPPER('tom');
-- COL1: TOM

-- # regexp_like
-- # regexp_like('Hello World', 'o W')
VALUES 'Hello World' SIMILAR TO '%' || 'o W' || '%';
-- COL1: TRUE

-- # to_char
-- # to_char(125.8, 'FM999.9')
VALUES CAST(125.8 AS VARCHAR(10));
-- COL1: 125.8

-- # to_char(TIMESTAMP '2024-03-15 10:30:00', 'YYYY-MM-DD HH24:MI')
VALUES CAST(TIMESTAMP '2024-03-15 10:30:00' AS VARCHAR(16) FORMAT 'YYYY-MM-DD HH24:MI');
-- COL1: 2024-03-15 10:30

-- # to_date
-- # to_date('15/03/2024', 'DD/MM/YYYY')
VALUES CAST('15/03/2024' AS DATE FORMAT 'DD/MM/YYYY');
-- COL1: 2024-03-15

-- # to_number
-- # to_number('125.8', '999.9')
VALUES CAST('125.8' AS DECIMAL(10, 1));
-- COL1: 125.8

-- # to_timestamp
-- # to_timestamp('15/03/2024 10:30', 'DD/MM/YYYY HH24:MI')
VALUES CAST('15/03/2024 10:30' AS TIMESTAMP(0) FORMAT 'DD/MM/YYYY HH24:MI');
-- COL1: 2024-03-15T10:30:00

-- # clock_timestamp
/* extensions V402-01 */
-- # clock_timestamp() > '2020-01-01'
VALUES NOW() > TIMESTAMP '2020-01-01 00:00:00+00:00';
-- COL1: TRUE

-- # current_date
-- # current_date = CAST(current_timestamp AS date)
VALUES CURRENT_DATE = CAST(CURRENT_TIMESTAMP AS DATE);
-- COL1: TRUE

-- # current_time
-- # current_time(0) IS NOT NULL
VALUES CURRENT_TIME(0) IS NOT NULL;
-- COL1: TRUE

-- # current_timestamp
-- # current_timestamp > '2020-01-01'
VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
-- COL1: TRUE

-- # date_part
-- # date_part('year', timestamp '2024-03-15 10:30:00')
VALUES EXTRACT(YEAR FROM TIMESTAMP '2024-03-15 10:30:00');
-- COL1: 2024

-- # date_trunc
-- # date_trunc('day', timestamp '2024-03-15 10:30:00')
VALUES CAST(CAST(TIMESTAMP '2024-03-15 10:30:00' AS DATE) AS TIMESTAMP(0));
-- COL1: 2024-03-15T00:00:00

-- # extract
-- # extract(hour FROM timestamp '2024-03-15 10:30:00')
VALUES EXTRACT(HOUR FROM TIMESTAMP '2024-03-15 10:30:00');
-- COL1: 10

-- # localtime
-- # localtime(0) IS NOT NULL
VALUES LOCALTIME(0) IS NOT NULL;
-- COL1: TRUE

-- # localtimestamp
-- # localtimestamp > '2020-01-01'
VALUES LOCALTIMESTAMP > TIMESTAMP '2020-01-01 00:00:00';
-- COL1: TRUE

-- # make_date
-- # make_date(2013, 7, 15)
VALUES MAKE_DATE(2013, 7, 15);
-- COL1: 2013-07-15

-- # make_time
-- # make_time(8, 15, 23)
VALUES MAKE_TIME(8, 15, 23);
-- COL1: 08:15:23.000000

-- # make_timestamp
-- # make_timestamp(2013, 7, 15, 8, 15, 23.5)
VALUES MAKE_TIMESTAMP(2013, 7, 15, 8, 15, 23.5);
-- COL1: 2013-07-15T08:15:23.500000

-- # make_timestamptz
-- # make_timestamptz(2013, 7, 15, 8, 15, 23.5, '-08:00')
VALUES MAKE_TIMESTAMPTZ(2013, 7, 15, 8, 15, 23.5, '-08:00');
-- COL1: 2013-07-15T08:15:23.500000-0800

-- # now
-- # now() > '2020-01-01'
VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
-- COL1: TRUE

-- # statement_timestamp
-- # statement_timestamp() > '2020-01-01'
VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
-- COL1: TRUE

-- # timeofday
/* extensions V402-01 */
-- # timeofday() IS NOT NULL
VALUES NOW() IS NOT NULL;
-- COL1: TRUE

-- # timezone
-- # timezone(timestamptz '2022-07-04 12:00:00+00') = timestamptz '2022-07-04 12:00:00+00'
VALUES (TIMESTAMP '2022-07-04 12:00:00+00:00' AT LOCAL) = TIMESTAMP '2022-07-04 12:00:00+00:00';
-- COL1: TRUE

-- # transaction_timestamp
-- # transaction_timestamp() > '2020-01-01'
VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
-- COL1: TRUE

-- # nextval
-- # nextval('ids')
SELECT NEXT VALUE FOR ids FROM (VALUES 1) AS t;
-- COL1: 1

-- # setval
-- # setval('ids', 42)
ALTER SEQUENCE ids RESTART WITH 43;
-- msg: ALTER SEQUENCE 1

-- # setval
-- # setval('ids', 42, false)
ALTER SEQUENCE ids RESTART WITH 42;
-- msg: ALTER SEQUENCE 1

-- # COALESCE
-- # COALESCE(NULL, 2, 3)
VALUES COALESCE(CAST(NULL AS INTEGER), 2, 3);
-- COL1: 2

-- # GREATEST
-- # GREATEST(1, 3, 2)
VALUES GREATEST(1, 3, 2);
-- COL1: 3

-- # LEAST
-- # LEAST(5, 2, 9)
VALUES LEAST(5, 2, 9);
-- COL1: 2

-- # NULLIF
-- # NULLIF(5, 5)
VALUES NULLIF(5, 5);
-- COL1: NULL

-- # any_value
-- # SELECT any_value(sku) FROM products WHERE qty = 40
SELECT ANY_VALUE(sku) FROM products WHERE qty = 40;
-- COL1: B2

-- # avg
-- # SELECT avg(price) FROM products
SELECT AVG(price) FROM products;
-- COL1: 2.1875000000000000

-- # bit_and
-- # SELECT bit_and(qty) FROM products
SELECT BIT_AND(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 0

-- # bit_or
-- # SELECT bit_or(qty) FROM products
SELECT BIT_OR(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 47

-- # bit_xor
-- # SELECT bit_xor(qty) FROM products
SELECT BIT_XOR(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 39

-- # bool_and
-- # SELECT bool_and(qty > 4) FROM products
SELECT EVERY(qty > 4) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: TRUE

-- # bool_or
-- # SELECT bool_or(qty > 30) FROM products
SELECT SOME(qty > 30) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: TRUE

-- # corr
-- # SELECT corr(price, qty) FROM products
SELECT CORR(price, qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: -0.835766105671e0

-- # count
-- # SELECT count(*) FROM products
SELECT COUNT(*) FROM products;
-- COL1: 4

-- # count
-- # SELECT count(qty) FROM products
SELECT COUNT(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 3

-- # covar_pop
-- # SELECT covar_pop(price, qty) FROM products
SELECT COVAR_POP(price, qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: -20.138888888889e0

-- # covar_samp
-- # SELECT covar_samp(price, qty) FROM products
SELECT COVAR_SAMP(price, qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: -30.208333333333e0

-- # cume_dist
-- # SELECT cume_dist(2.00) WITHIN GROUP (ORDER BY price) FROM products
SELECT CUME_DIST(2.00) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 0.6e0

-- # dense_rank
-- # SELECT dense_rank(2.00) WITHIN GROUP (ORDER BY price) FROM products
SELECT DENSE_RANK(2.00) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 3

-- # every
-- # SELECT every(qty > 4) FROM products
SELECT EVERY(qty > 4) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: TRUE

-- # max
-- # SELECT max(price) FROM products
SELECT MAX(price) FROM products;
-- COL1: 4.00

-- # min
-- # SELECT min(price) FROM products
SELECT MIN(price) FROM products;
-- COL1: 0.25

-- # mode
/* extensions V405-01 */
-- # SELECT mode() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v)
SELECT MODE() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
-- COL1: 2

-- # percent_rank
-- # SELECT percent_rank(2.00) WITHIN GROUP (ORDER BY price) FROM products
SELECT PERCENT_RANK(2.00) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 0.5e0

-- # percentile_cont
-- # SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY price) FROM products
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 2.25e0

-- # percentile_disc
-- # SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY price) FROM products
SELECT PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 1.5e0

-- # rank
-- # SELECT rank(2.00) WITHIN GROUP (ORDER BY price) FROM products
SELECT RANK(2.00) WITHIN GROUP (ORDER BY price) FROM products;
-- COL1: 3

-- # regr_avgx
-- # SELECT regr_avgx(qty, price) FROM products
SELECT REGR_AVGX(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 1.916666666667e0

-- # regr_avgy
-- # SELECT regr_avgy(qty, price) FROM products
SELECT REGR_AVGY(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 18.333333333333e0

-- # regr_count
-- # SELECT regr_count(qty, price) FROM products
SELECT REGR_COUNT(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 3

-- # regr_intercept
-- # SELECT regr_intercept(qty, price) FROM products
SELECT REGR_INTERCEPT(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 34.214285714286e0

-- # regr_r2
-- # SELECT regr_r2(qty, price) FROM products
SELECT REGR_R2(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 0.698504983389e0

-- # regr_slope
-- # SELECT regr_slope(qty, price) FROM products
SELECT REGR_SLOPE(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: -8.285714285714e0

-- # regr_sxx
-- # SELECT regr_sxx(qty, price) FROM products
SELECT REGR_SXX(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 7.291666666667e0

-- # regr_sxy
-- # SELECT regr_sxy(qty, price) FROM products
SELECT REGR_SXY(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: -60.416666666667e0

-- # regr_syy
-- # SELECT regr_syy(qty, price) FROM products
SELECT REGR_SYY(qty, price) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 716.666666666667e0

-- # stddev
-- # SELECT stddev(qty) FROM products
SELECT STDDEV_SAMP(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 18.929694486001e0

-- # stddev_pop
-- # SELECT stddev_pop(qty) FROM products
SELECT STDDEV_POP(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 15.456030825826e0

-- # stddev_samp
-- # SELECT stddev_samp(qty) FROM products
SELECT STDDEV_SAMP(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 18.929694486001e0

-- # string_agg
-- # SELECT string_agg(name, ', ' ORDER BY name) FROM products
SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY name) FROM products;
-- COL1: Apple, Banana, Cherry, Date

-- # sum
-- # SELECT sum(qty) FROM products
SELECT SUM(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 55

-- # var_pop
-- # SELECT var_pop(qty) FROM products
SELECT VAR_POP(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 238.888888888889e0

-- # var_samp
-- # SELECT var_samp(qty) FROM products
SELECT VAR_SAMP(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 358.333333333333e0

-- # variance
-- # SELECT variance(qty) FROM products
SELECT VAR_SAMP(qty) FROM products;
-- warning 01003: null value eliminated in set function
-- COL1: 358.333333333333e0

-- # first_value
-- # SELECT name, first_value(name) OVER (ORDER BY price) FROM products
SELECT name, (SELECT q.name FROM products q ORDER BY q.price FETCH FIRST 1 ROW ONLY) FROM products p ORDER BY price;
-- NAME: Banana COL2: Banana
-- NAME: Apple COL2: Banana
-- NAME: Date COL2: Banana
-- NAME: Cherry COL2: Banana

-- # lag
-- # SELECT name, lag(price) OVER (ORDER BY price) FROM products
SELECT name, (SELECT MAX(q.price) FROM products q WHERE q.price < p.price) FROM products p ORDER BY price;
-- NAME: Banana COL2: NULL
-- NAME: Apple COL2: 0.25
-- NAME: Date COL2: 1.50
-- NAME: Cherry COL2: 3.00

-- # last_value
-- # SELECT name, last_value(name) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) FROM products ORDER BY price
SELECT name, (SELECT q.name FROM products q ORDER BY q.price DESC FETCH FIRST 1 ROW ONLY) FROM products p ORDER BY price;
-- NAME: Banana COL2: Cherry
-- NAME: Apple COL2: Cherry
-- NAME: Date COL2: Cherry
-- NAME: Cherry COL2: Cherry

-- # lead
-- # SELECT name, lead(price) OVER (ORDER BY price) FROM products
SELECT name, (SELECT MIN(q.price) FROM products q WHERE q.price > p.price) FROM products p ORDER BY price;
-- NAME: Banana COL2: 1.50
-- NAME: Apple COL2: 3.00
-- NAME: Date COL2: 4.00
-- NAME: Cherry COL2: NULL

-- # row_number
-- # SELECT name, row_number() OVER (ORDER BY price) FROM products
SELECT name, (SELECT COUNT(*) FROM products q WHERE q.price <= p.price) FROM products p ORDER BY price;
-- NAME: Banana COL2: 1
-- NAME: Apple COL2: 2
-- NAME: Date COL2: 3
-- NAME: Cherry COL2: 4

-- # generate_series
-- # SELECT * FROM generate_series(1, 3)
SELECT n FROM (VALUES 1, 2, 3) AS t (n) ORDER BY n;
-- N: 1
-- N: 2
-- N: 3

-- # current_catalog
-- # current_catalog
VALUES CURRENT_CATALOG;
-- COL1: :memory:

-- # current_database
-- # current_database()
VALUES CURRENT_CATALOG;
-- COL1: :memory:

-- # current_schema
-- # current_schema
VALUES CURRENT_SCHEMA;
-- COL1: PUBLIC
