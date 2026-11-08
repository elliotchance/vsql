EXPLAIN SET CATALOG 'foo';
-- error 42601: syntax error: Cannot EXPLAIN SET CATALOG

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
