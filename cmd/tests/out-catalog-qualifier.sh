#!/bin/sh

# A dump of a table with a catalog name in a CHECK or generation expression can
# be loaded into a file with another name, which is another catalog.

set -e

DIR="$(mktemp -d)" || exit 1

cat <<EOF | $VSQL in $DIR/a.vsql
CREATE SCHEMA s;
CREATE TABLE s.t (x INT CHECK ("a".s.t.x > 0), y INT GENERATED ALWAYS AS ("a".s.t.x + 1));
INSERT INTO s.t (x) VALUES (1);
EOF

$VSQL out $DIR/a.vsql > $DIR/dump.sql
$VSQL in $DIR/c.vsql < $DIR/dump.sql

# The dump of the file that it was loaded into is the same.
$VSQL out $DIR/c.vsql > $DIR/dump2.sql
diff $DIR/dump.sql $DIR/dump2.sql

# The definitions still work.
echo 'SELECT * FROM s.t; INSERT INTO s.t (x) VALUES (0);' | $VSQL cli $DIR/c.vsql > $DIR/out.txt 2>&1 || true
cat $DIR/out.txt
grep -F 'violates check constraint' $DIR/out.txt
