/* types */
VALUES ROW(ABS(1.2), ABS(-1.23));
-- COL1: 1.2 (NUMERIC(2, 1)) COL2: 1.23 (NUMERIC(3, 2))

/* types */
VALUES ROW(ABS(1.2e0), ABS(-1.23e0));
-- COL1: 1.2e0 (DOUBLE PRECISION) COL2: 1.23e0 (DOUBLE PRECISION)

VALUES ABS('hello');
-- error 42883: function does not exist: ABS(CHARACTER(5))

VALUES ABS();
-- error 42601: syntax error: near ")"

VALUES ABS(1, 2);
-- error 42601: syntax error: near ","

/* types */
VALUES MOD(232.0, 3.0);
-- COL1: 1 (NUMERIC(4, 1))

/* types */
VALUES MOD(10.7, 0.8);
-- COL1: 0.3 (NUMERIC(3, 1))

/* types */
VALUES MOD(232.000, 3.0);
-- COL1: 1 (NUMERIC(6, 3))

/* types */
VALUES MOD(232., 3.0000);
-- COL1: 1 (NUMERIC(10, 4))

/* types */
VALUES ROW(FLOOR(3.7), FLOOR(3.3), FLOOR(-3.7), FLOOR(-3.3));
-- COL1: 3 (NUMERIC(1)) COL2: 3 (NUMERIC(1)) COL3: -4 (NUMERIC(1)) COL4: -4 (NUMERIC(1))

/* types */
VALUES ROW(CEIL(3.7), CEIL(3.3), CEIL(-3.7), CEIL(-3.3));
-- COL1: 4 (NUMERIC(1)) COL2: 4 (NUMERIC(1)) COL3: -3 (NUMERIC(1)) COL4: -3 (NUMERIC(1))

/* types */
VALUES CEILING(3.7);
-- COL1: 4 (NUMERIC(1))

/* types */
VALUES SIN(1.2e0);
-- COL1: 0.932039085967e0 (DOUBLE PRECISION)

/* types */
VALUES COS(1.2e0);
-- COL1: 0.362357754477e0 (DOUBLE PRECISION)

/* types */
VALUES TAN(1.2e0);
-- COL1: 2.572151622126e0 (DOUBLE PRECISION)

/* types */
VALUES SINH(1.2e0);
-- COL1: 1.509461355412e0 (DOUBLE PRECISION)

/* types */
VALUES COSH(1.2e0);
-- COL1: 1.810655567324e0 (DOUBLE PRECISION)

/* types */
VALUES TANH(1.2e0);
-- COL1: 0.833654607012e0 (DOUBLE PRECISION)

/* types */
VALUES ASIN(0.2e0);
-- COL1: 0.20135792079e0 (DOUBLE PRECISION)

/* types */
VALUES ACOS(0.2e0);
-- COL1: 1.369438406005e0 (DOUBLE PRECISION)

/* types */
VALUES ATAN(0.2e0);
-- COL1: 0.19739555985e0 (DOUBLE PRECISION)

/* types */
VALUES MOD(232e0, 3e0);
-- COL1: 1e0 (DOUBLE PRECISION)

/* types */
VALUES MOD(10.7e0, 0.8e0);
-- COL1: 0.3e0 (DOUBLE PRECISION)

/* types */
VALUES LOG10(13.7e0);
-- COL1: 1.136720567156e0 (DOUBLE PRECISION)

/* types */
VALUES LN(13.7e0);
-- COL1: 2.617395832834e0 (DOUBLE PRECISION)

/* types */
VALUES EXP(3.7e0);
-- COL1: 40.447304360067e0 (DOUBLE PRECISION)

/* types */
VALUES POWER(3.7e0, 2.5e0);
-- COL1: 26.333240780428e0 (DOUBLE PRECISION)

/* types */
VALUES SQRT(3.7e0);
-- COL1: 1.923538406167e0 (DOUBLE PRECISION)

/* types */
VALUES ROW(FLOOR(3.7e0), FLOOR(3.3e0), FLOOR(-3.7e0), FLOOR(-3.3e0));
-- COL1: 3e0 (DOUBLE PRECISION) COL2: 3e0 (DOUBLE PRECISION) COL3: -4e0 (DOUBLE PRECISION) COL4: -4e0 (DOUBLE PRECISION)

/* types */
VALUES ROW(CEIL(3.7e0), CEIL(3.3e0), CEIL(-3.7e0), CEIL(-3.3e0));
-- COL1: 4e0 (DOUBLE PRECISION) COL2: 4e0 (DOUBLE PRECISION) COL3: -3e0 (DOUBLE PRECISION) COL4: -3e0 (DOUBLE PRECISION)

/* types */
VALUES CEILING(3.7e0);
-- COL1: 4e0 (DOUBLE PRECISION)
