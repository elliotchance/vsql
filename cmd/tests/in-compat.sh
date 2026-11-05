#!/bin/sh

set -e

# This changes to a temporary directory, and VSQL can be a relative path.
VSQL="$(realpath "$VSQL")"

DIR="$(mktemp -d)" || exit 1
VSQL_FILE="$DIR/test.vsql"
cd "$DIR"

query() {
    echo "$1" | $VSQL cli $VSQL_FILE
}

# This is what the SQLite version of the Chinook database looks like. A table
# refers to one that's created later, and the rows are in any order.
cat > sqlite.sql <<'SQL'
/* A comment; it's here. */
PRAGMA foreign_keys = OFF;
DROP TABLE IF EXISTS [Album];
CREATE TABLE [Album]
(
    [AlbumId] INTEGER  NOT NULL,
    [Title] NVARCHAR(160)  NOT NULL,
    `ArtistId` INTEGER  NOT NULL,
    Released DATETIME,
    CONSTRAINT [PK_Album] PRIMARY KEY  ([AlbumId]),
    FOREIGN KEY ([ArtistId]) REFERENCES [Artist] ([ArtistId])
		ON DELETE NO ACTION ON UPDATE NO ACTION
);
CREATE TABLE "Artist"
(
    [ArtistId] INTEGER  NOT NULL, -- The id.
    [Name] NVARCHAR(120),
    [Code] NCHAR(2),
    CONSTRAINT [PK_Artist] PRIMARY KEY  ([ArtistId])
);
CREATE INDEX [IFK_AlbumArtistId] ON [Album] ([ArtistId]);
CREATE UNIQUE INDEX [IFK_Name] ON [Artist] ([Name]);
CREATE VIEW [V] AS SELECT [Name] FROM [Artist];
CREATE TRIGGER [T] AFTER INSERT ON [Artist] BEGIN
    UPDATE [Artist] SET [Name] = 'x';
    DELETE FROM [Artist];
END;
BEGIN TRANSACTION;
INSERT INTO [Album] ([AlbumId], [Title], [ArtistId], [Released]) VALUES
    (1, 'It''s, (a) ''title''', 1, '2002-08-14 00:00:00'),
    (2, 'Date', 1, '2002-08-15'),
    (3, 'T', 1, '2002-08-16T01:02:03'),
    (4, 'None', 1, NULL);
insert into album (Albumid, TITLE, artistid, released) VALUES (5, 'Case', 1, '2002-08-17 00:00:00');
INSERT INTO album VALUES(6, 'No columns', 1, '2002-08-18 00:00:00');
INSERT INTO [Artist] ([ArtistId], [Name]) VALUES (1, 'Björk');
COMMIT;
SQL

# Without -ignore-unsupported they are errors. What's in the body of the trigger
# isn't run by itself.
$VSQL in -file sqlite.sql -compat sqlite3 -continue-on-error $VSQL_FILE > out.txt && exit 1
test "$(grep -c ' ERROR ' out.txt)" = 4
query 'SELECT name FROM artist;' | grep -x 'Björk'
rm -f $VSQL_FILE $VSQL_FILE.wal

$VSQL in -file sqlite.sql -compat sqlite3 -ignore-unsupported -verbose $VSQL_FILE > out.txt
test "$(grep -c ' CREATE TABLE 1$' out.txt)" = 2
grep -E '^3 [0-9]+/[0-9]+ DROP TABLE 0$' out.txt
grep ' START TRANSACTION$' out.txt
grep ' COMMIT$' out.txt
if grep -q ' ERROR ' out.txt; then exit 1; fi
grep '^22 .* WARNING 01000 CREATE INDEX is not supported, so it was ignored' out.txt
grep 'CREATE VIEW is not supported' out.txt
grep 'CREATE TRIGGER is not supported' out.txt

# A FOREIGN KEY is added at the end, with the line of its table.
grep -E '^4 [0-9]+/[0-9]+ ALTER TABLE 1$' out.txt

# Names aren't case sensitive.
query 'SELECT name FROM artist;' | grep -x 'Björk'
query "SELECT title FROM album WHERE albumid = 1;" | grep -Fx "It's, (a) 'title'"
query 'SELECT COUNT(*) AS c FROM "ALBUM";' | grep -E '^ *6$'

# The types, and the strings of a DATETIME.
query "SELECT data_type FROM information_schema.columns WHERE column_name = 'RELEASED';" | grep 'TIMESTAMP'
query "SELECT data_type FROM information_schema.columns WHERE column_name = 'TITLE';" | grep 'CHARACTER VARYING'
query "SELECT albumid FROM album WHERE released = TIMESTAMP '2002-08-15 00:00:00';" | grep -E '^ *2$'
query "SELECT albumid FROM album WHERE released = TIMESTAMP '2002-08-16 01:02:03';" | grep -E '^ *3$'
query "SELECT albumid FROM album WHERE released = TIMESTAMP '2002-08-17 00:00:00';" | grep -E '^ *5$'
query "SELECT albumid FROM album WHERE released = TIMESTAMP '2002-08-18 00:00:00';" | grep -E '^ *6$'

# The FOREIGN KEY is there.
query "INSERT INTO album (albumid, title, artistid) VALUES (9, 'x', 9);" | grep 23503

# DROP TABLE IF EXISTS drops it, if nothing refers to it.
printf 'DROP TABLE IF EXISTS [Album];\nDROP TABLE IF EXISTS [Nope];\n' > drop.sql
$VSQL in -file drop.sql -compat sqlite3 -verbose $VSQL_FILE > out.txt
grep ' DROP TABLE 1$' out.txt
grep ' DROP TABLE 0$' out.txt
query 'SELECT * FROM album;' | grep -i 'no such table'

# A trigger without -compat is also put back together.
printf 'CREATE TRIGGER t AFTER INSERT ON x BEGIN\nDELETE FROM x;\nEND;\nCREATE TABLE z (a INT);\n' > t.sql
$VSQL in -file t.sql -ignore-unsupported -verbose $VSQL_FILE > out.txt
test "$(grep -c ' WARNING ' out.txt)" = 1
grep -E '^4 [0-9]+/[0-9]+ CREATE TABLE 1$' out.txt
query 'SELECT * FROM z;' | grep -i 'no data\|0 rows'

# Bad options.
$VSQL in -compat nope $VSQL_FILE < /dev/null && exit 1
$VSQL in -compat sqlite3 -format csv -table z $VSQL_FILE < /dev/null && exit 1

rm -rf "$DIR"
