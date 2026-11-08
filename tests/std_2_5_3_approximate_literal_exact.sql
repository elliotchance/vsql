-- # A literal with an exponent is a DOUBLE PRECISION (Syntax Rules, 23), up to
-- # the largest double, and the mantissa can start or end with the period.
/* types */
VALUES ROW(1.7976931348623157e+308, 1e+20, 1.E2, .5e2);
-- COL1: 1.79769313486e+308 (DOUBLE PRECISION) COL2: 1e+20 (DOUBLE PRECISION) COL3: 100e0 (DOUBLE PRECISION) COL4: 50e0 (DOUBLE PRECISION)

-- # The value is the nearest double (General Rules, 5): the smallest subnormal
-- # is above zero, 0.1e0 + 0.2e0 is the double just above 0.3e0, and digits
-- # past the precision of a double are lost, so 2^53 + 1 is the same as 2^53.
VALUES ROW(5e-324 > 0e0, 0.30000000000000004e0 = 0.1e0 + 0.2e0, 0.3e0 = 0.1e0 + 0.2e0);
-- COL1: TRUE COL2: TRUE COL3: FALSE

VALUES ROW(1.2345678901234568e+17 = 123456789012345678e0, 9007199254740993e0 = 9007199254740992e0);
-- COL1: TRUE COL2: TRUE
