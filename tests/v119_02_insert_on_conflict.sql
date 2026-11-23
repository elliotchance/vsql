/* setup */
CREATE TABLE posts (id INT NOT NULL PRIMARY KEY, slug VARCHAR(20) UNIQUE, title VARCHAR(50), views INT DEFAULT 0);
INSERT INTO posts (id, slug, title) VALUES (1, 'home', 'Home'), (2, 'about', 'About');

-- # ON CONFLICT is a vsql extension (like PostgreSQL and SQLite).
/* flags */
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'home', 'Home') ON CONFLICT DO NOTHING;
-- flags: V119-02
-- msg: INSERT 0

-- # Without a conflict target, DO NOTHING skips a row that conflicts in any
-- # PRIMARY KEY, UNIQUE constraint or UNIQUE index.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'x', 'X'), (3, 'about', 'A'), (4, 'contact', 'Contact') ON CONFLICT DO NOTHING;
SELECT * FROM posts;
-- msg: INSERT 1
-- ID: 1 SLUG: home TITLE: Home VIEWS: 0
-- ID: 2 SLUG: about TITLE: About VIEWS: 0
-- ID: 4 SLUG: contact TITLE: Contact VIEWS: 0

-- # With a conflict target, only that constraint is used, so a conflict in
-- # another one is still an error.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'x', 'X') ON CONFLICT (id) DO NOTHING;
INSERT INTO posts (id, slug, title) VALUES (3, 'home', 'X') ON CONFLICT (id) DO NOTHING;
-- msg: INSERT 0
-- error 23505: violates unique constraint: UNIQUE (SLUG) on ":memory:".PUBLIC.POSTS

-- # DO UPDATE changes the existing row instead. EXCLUDED is the row that would
-- # have been inserted, and the table's name is the existing row.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'home', 'Welcome'), (3, 'blog', 'Blog')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, views = posts.views + 1;
SELECT * FROM posts;
-- msg: INSERT 2
-- ID: 1 SLUG: home TITLE: Welcome VIEWS: 1
-- ID: 2 SLUG: about TITLE: About VIEWS: 0
-- ID: 3 SLUG: blog TITLE: Blog VIEWS: 0

-- # The conflict target can be any PRIMARY KEY, UNIQUE constraint or UNIQUE
-- # index with exactly those columns.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (10, 'about', 'About us') ON CONFLICT (slug) DO UPDATE SET title = excluded.title;
SELECT * FROM posts WHERE slug = 'about';
-- msg: INSERT 1
-- ID: 2 SLUG: about TITLE: About us VIEWS: 0

/* extensions V119-02 */
INSERT INTO posts (id) VALUES (1) ON CONFLICT (title) DO NOTHING;
-- error 42601: syntax error: there is no PRIMARY KEY, UNIQUE constraint or UNIQUE index on ":memory:".PUBLIC.POSTS for ON CONFLICT (TITLE)

/* extensions V119-02 */
INSERT INTO posts (id) VALUES (1) ON CONFLICT (nope) DO NOTHING;
-- error 42703: no such column: NOPE

-- # A WHERE only updates the rows where it's true. The other rows are
-- # skipped, and aren't counted.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'home', 'Welcome'), (2, 'about', 'About')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title WHERE posts.title <> EXCLUDED.title;
SELECT * FROM posts;
-- msg: INSERT 1
-- ID: 1 SLUG: home TITLE: Welcome VIEWS: 0
-- ID: 2 SLUG: about TITLE: About VIEWS: 0

-- # A row that's updated to the same values is still counted.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'home', 'Home') ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
-- msg: INSERT 1

-- # A column that isn't qualified is in both the table and EXCLUDED.
/* extensions V119-02 */
INSERT INTO posts (id) VALUES (1) ON CONFLICT (id) DO UPDATE SET views = views + 1;
-- error 42702: ambiguous column: VIEWS

-- # DO UPDATE needs a conflict target.
INSERT INTO posts (id) VALUES (1) ON CONFLICT DO UPDATE SET views = 1;
-- error 42601: syntax error: unexpected UPDATE at line 1, column 50 near ") ON CONFLICT DO UPDATE SET", expecting NOTHING

-- # A row can only be updated once, because the result would depend on the
-- # order of the rows. That includes a row that the same INSERT inserted.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'home', 'A'), (1, 'home', 'B') ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO posts (id, slug, title) VALUES (5, 'five', 'A'), (5, 'five', 'B') ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
SELECT * FROM posts;
-- error 21000: cardinality violation: ON CONFLICT DO UPDATE cannot change the same row of ":memory:".PUBLIC.POSTS more than once
-- error 21000: cardinality violation: ON CONFLICT DO UPDATE cannot change the same row of ":memory:".PUBLIC.POSTS more than once
-- ID: 1 SLUG: home TITLE: Home VIEWS: 0
-- ID: 2 SLUG: about TITLE: About VIEWS: 0

-- # DO NOTHING skips a row that conflicts with one that the same INSERT
-- # inserted, so the first one wins.
/* extensions V119-02 */
INSERT INTO posts (id, slug, title) VALUES (5, 'five', 'A'), (5, 'five', 'B') ON CONFLICT DO NOTHING;
SELECT * FROM posts WHERE id = 5;
-- msg: INSERT 1
-- ID: 5 SLUG: five TITLE: A VIEWS: 0

-- # A query without any rows is a no data warning, like any INSERT.
/* extensions V119-02 */
INSERT INTO posts SELECT * FROM posts WHERE id > 10 ON CONFLICT DO NOTHING;
-- warning 02000: no data
-- msg: INSERT 0

-- # A NULL never conflicts in a UNIQUE constraint.
/* extensions V119-02 */
INSERT INTO posts (id, slug) VALUES (6, NULL), (7, NULL) ON CONFLICT (slug) DO NOTHING;
-- msg: INSERT 2

-- # RETURNING and NEW TABLE have the rows that were inserted or updated.
/* extensions V119-01 V119-02 */
INSERT INTO posts (id, slug, title) VALUES (1, 'home', 'Home'), (8, 'eight', 'Eight'), (2, 'about', 'X')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title WHERE posts.id = 1 RETURNING id, title;
-- ID: 1 TITLE: Home
-- ID: 8 TITLE: Eight

/* extensions V119-02 */
SELECT id, views FROM NEW TABLE (INSERT INTO posts (id, slug) VALUES (1, 'home'), (9, 'nine') ON CONFLICT (id) DO UPDATE SET views = posts.views + 10);
-- ID: 1 VIEWS: 10
-- ID: 9 VIEWS: 0

-- # An update that conflicts with another row is an error, and so is one that
-- # fails a CHECK or NOT NULL.
/* extensions V119-02 */
INSERT INTO posts (id, slug) VALUES (1, 'x') ON CONFLICT (id) DO UPDATE SET slug = 'about';
INSERT INTO posts (id, slug) VALUES (1, 'x') ON CONFLICT (id) DO UPDATE SET id = 2;
INSERT INTO posts (id, slug) VALUES (1, 'x') ON CONFLICT (id) DO UPDATE SET id = NULL;
-- error 23505: violates unique constraint: UNIQUE (SLUG) on ":memory:".PUBLIC.POSTS
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.POSTS
-- error 23502: violates non-null constraint: column ID

-- # An update can change the PRIMARY KEY.
/* extensions V119-02 */
INSERT INTO posts (id, slug) VALUES (2, 'x') ON CONFLICT (id) DO UPDATE SET id = 90;
SELECT id, slug FROM posts;
-- msg: INSERT 1
-- ID: 1 SLUG: home
-- ID: 90 SLUG: about

-- # Each <set clause> can only set a column once, to a value of its type.
/* extensions V119-02 */
INSERT INTO posts (id) VALUES (1) ON CONFLICT (id) DO UPDATE SET views = 1, views = 2;
INSERT INTO posts (id) VALUES (1) ON CONFLICT (id) DO UPDATE SET views = 'x';
-- error 42601: syntax error: column VIEWS is set more than once
-- error 42846: cannot coerce CHARACTER(1) to INTEGER

-- # A dynamic parameter in a <set clause> has the type of its column.
/* params 'Hello' */
/* extensions V119-02 */
INSERT INTO posts (id, slug) VALUES (1, 'home') ON CONFLICT (id) DO UPDATE SET title = ?;
SELECT title FROM posts WHERE id = 1;
-- sql: INSERT INTO posts (id, slug) VALUES (1, 'home') ON CONFLICT (id) DO UPDATE SET title = 'Hello'
-- msg: INSERT 1
-- TITLE: Hello

-- # ON CONSTRAINT names a PRIMARY KEY or UNIQUE constraint.
/* extensions V119-02 */
CREATE TABLE named (a INT, b INT, CONSTRAINT named_a UNIQUE (a));
INSERT INTO named VALUES (1, 1);
INSERT INTO named VALUES (1, 2) ON CONFLICT ON CONSTRAINT named_a DO UPDATE SET b = EXCLUDED.b;
INSERT INTO named VALUES (1, 3) ON CONFLICT ON CONSTRAINT nope DO NOTHING;
SELECT * FROM named;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 42704: no such constraint: NOPE on ":memory:".PUBLIC.NAMED
-- A: 1 B: 2

-- # A UNIQUE index can be the conflict target, but a DEFERRABLE constraint
-- # can't, since it can have duplicates until it's checked.
/* extensions V002-01 V002-02 V119-02 */
CREATE TABLE codes (code VARCHAR(10), n INT, u INT UNIQUE DEFERRABLE);
CREATE UNIQUE INDEX codes_code ON codes (code);
INSERT INTO codes (code, n) VALUES ('a', 1), ('a', 2) ON CONFLICT (code) DO UPDATE SET n = codes.n + EXCLUDED.n;
INSERT INTO codes (code, n, u) VALUES ('b', 1, 1) ON CONFLICT (u) DO NOTHING;
INSERT INTO codes (code, n, u) VALUES ('b', 1, 1) ON CONFLICT DO NOTHING;
SELECT code, n FROM codes;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- error 21000: cardinality violation: ON CONFLICT DO UPDATE cannot change the same row of ":memory:".PUBLIC.CODES more than once
-- error 42601: syntax error: ON CONFLICT cannot use CODES_UNIQUE_1 on ":memory:".PUBLIC.CODES, because it is DEFERRABLE
-- error 42601: syntax error: ON CONFLICT cannot use CODES_UNIQUE_1 on ":memory:".PUBLIC.CODES, because it is DEFERRABLE

/* extensions V002-01 V002-02 V119-02 */
CREATE TABLE counts (code VARCHAR(10), n INT);
CREATE UNIQUE INDEX counts_code ON counts (code);
INSERT INTO counts VALUES ('a', 1);
INSERT INTO counts VALUES ('a', 2), ('b', 5) ON CONFLICT (code) DO UPDATE SET n = counts.n + EXCLUDED.n;
SELECT * FROM counts;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- msg: INSERT 2
-- CODE: a N: 3
-- CODE: b N: 5

-- # CONFLICT, DO, NOTHING and EXCLUDED are still names.
/* extensions V119-02 */
CREATE TABLE conflict (do INT NOT NULL PRIMARY KEY, nothing INT, excluded INT);
INSERT INTO conflict (do, nothing) VALUES (1, 2) ON CONFLICT (do) DO UPDATE SET nothing = EXCLUDED.nothing;
INSERT INTO conflict (do, nothing) VALUES (1, 3) ON CONFLICT (do) DO UPDATE SET excluded = EXCLUDED.nothing;
SELECT * FROM conflict JOIN posts ON conflict.do = posts.id;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- DO: 1 NOTHING: 2 EXCLUDED: 3 ID: 1 SLUG: home TITLE: Home VIEWS: 0

-- # A row that another transaction has inserted, and not yet committed, might
-- # or might not be a conflict, so it's a serialization failure instead of
-- # waiting, like a PRIMARY KEY or UNIQUE constraint.
/* extensions V119-02 */
/* connection 1 */
CREATE TABLE t (id INT NOT NULL PRIMARY KEY, u INT UNIQUE);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t VALUES (1, 1);
/* connection 2 */
INSERT INTO t VALUES (1, 2) ON CONFLICT (id) DO NOTHING;
INSERT INTO t VALUES (2, 1) ON CONFLICT (u) DO NOTHING;
/* connection 1 */
COMMIT;
/* connection 2 */
INSERT INTO t VALUES (1, 2), (2, 1), (3, 3) ON CONFLICT DO NOTHING;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: ID: 1 U: 1
-- 2: ID: 3 U: 3
