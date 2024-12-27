-- # There are some special tokens that are required to reduce the ambiguity for
-- # the parser. These tests ensure different whitespace combinations don't
-- # interfere with that.

-- # Reducing: "." "*". We don't care about the errors, only ensure there is no
-- # syntax errors.
SELECT x, count(*) FROM foo;
SELECT x, count( * ) FROM foo;
SELECT x, count (*) FROM foo;
SELECT x, count ( *) FROM foo;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
