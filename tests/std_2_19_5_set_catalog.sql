-- # SET CATALOG changes the session, so it can't be explained.
EXPLAIN SET CATALOG 'foo';
-- error 42601: syntax error: Cannot EXPLAIN SET CATALOG

-- # The current catalog is the name of the database (here ":memory:"). A
-- # catalog that doesn't exist is 3D000 and the current catalog doesn't change.
-- # vsql deviates from General Rules, 2 here: the value must be the name of an
-- # existing catalog, rather than anything that's a valid catalog name (#231).
VALUES CURRENT_CATALOG;
-- COL1: :memory:

SET CATALOG ':memory:';
VALUES CURRENT_CATALOG;
-- msg: SET CATALOG 1
-- COL1: :memory:

SET CATALOG 'foo';
VALUES CURRENT_CATALOG;
-- error 3D000: invalid catalog name: foo
-- COL1: :memory:
