-- # The test runner skips every description line, wherever it is: in a block
-- # of its own, between a statement and its expected output, or at the end.
-- # The following tests are arithmetic.

-- # Adding
VALUES 1 + 2;
-- COL1: 3

VALUES 3 * 4;
-- # Comments can be nested,
-- COL1: 12
-- # .. and afterwards.
