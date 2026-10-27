#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
HTML_FILE="$(mktemp)" || exit 1
PORT=3297
URL="http://127.0.0.1:$PORT/"

echo "CREATE TABLE \"my <t>\" (x INT, s VARCHAR(10)); INSERT INTO \"my <t>\" (x, s) VALUES (1, 'a&b'), (NULL, NULL); CREATE SCHEMA foo; CREATE TABLE foo.bar (y BOOLEAN); CREATE TABLE pk (id INT PRIMARY KEY, name VARCHAR(20), ts TIMESTAMP(0), g INT GENERATED ALWAYS AS (id * 2), b BOOLEAN); INSERT INTO pk (id, name) VALUES (1, 'a');" | $VSQL in $VSQL_FILE

$VSQL app -p $PORT $VSQL_FILE &
APP_PID=$!
trap 'kill $APP_PID' EXIT
sleep 2

# The first time there are no tabs (VSQL_APP.TABS is empty), so the home tab is
# active. It lists the tables under their schema (including VSQL_APP.TABS).
curl -sf $URL > $HTML_FILE
grep -F '<input type="hidden" name="tab" value="0">' $HTML_FILE
grep -F '<span class="tab home active"><button type="submit" name="goto" value="0" title="Home"><svg' $HTML_FILE
grep -F '<details class="schema" open><summary>FOO <span class="count">1 table</span></summary><table class="tables"><tbody><tr><td>BAR</td><td><button type="submit" name="query" value="FOO.BAR">Query</button></td></tr></tbody></table></details>' $HTML_FILE
grep -F '<summary>PUBLIC <span class="count">2 tables</span></summary>' $HTML_FILE
grep -F '<tr><td>my &lt;t&gt;</td><td><button type="submit" name="query" value="PUBLIC.&quot;my &lt;t&gt;&quot;">Query</button></td></tr>' $HTML_FILE
grep -F 'title="New tab">+</button><span class="version">vsql v0.0.0</span></div>' $HTML_FILE
grep -F '<summary>VSQL_APP <span class="count">1 table</span></summary><table class="tables"><tbody><tr><td>TABS</td>' $HTML_FILE
echo 'SELECT COUNT(*) FROM vsql_app.tabs;' | $VSQL cli $VSQL_FILE | grep -E '^ *0$'

# Query opens a new tab that runs SELECT * on the table. The editor colors
# reserved words (but not non-reserved words like NAME).
curl -sf $URL -d tab=0 --data-urlencode 'query=PUBLIC."my <t>"' -D - -o /dev/null | grep -F 'Location: /'
curl -sf $URL > $HTML_FILE
grep -F '<span class="tab home"><button type="submit" name="goto" value="0" title="Home">' $HTML_FILE
grep -F '<span class="tab active"><button type="submit" name="goto" value="1">SELECT * FROM PUBLIC.&quot;my &lt;t&gt;&quot;</button>' $HTML_FILE
grep -F '>SELECT * FROM PUBLIC.&quot;my &lt;t&gt;&quot;</textarea>' $HTML_FILE
grep -F '<span class="status">2 rows (' $HTML_FILE
grep -F '<td>a&amp;b</td>' $HTML_FILE
grep -F '<button type="submit" class="run" title="Run (Ctrl+Enter)">Run <span class="shortcut">&#8963;&#8629;</span></button>' $HTML_FILE
grep -F '"SELECT"' $HTML_FILE
if grep -F '"NAME"' $HTML_FILE; then exit 1; fi

# Adding a tab saves the SQL of the current tab first (but not its title, that
# is only set when it's run) and makes the new tab active. A new tab shows the
# tables.
curl -sf $URL -d tab=1 --data-urlencode 'sql=SELECT * FROM "PUBLIC"."my <t>"' -d new=1 -D - -o /dev/null | grep -F 'Location: /'
curl -sf $URL > $HTML_FILE
grep -F '<span class="tab"><button type="submit" name="goto" value="1">SELECT * FROM PUBLIC.&quot;my &lt;t&gt;&quot;</button>' $HTML_FILE
grep -F '<span class="tab active"><button type="submit" name="goto" value="2">SELECT * FROM INFORMATION_SCHE...</button>' $HTML_FILE
grep -F '>SELECT * FROM INFORMATION_SCHEMA.TABLES</textarea>' $HTML_FILE
grep -F 'Run to see the result.' $HTML_FILE

# Running shows the result of the last statement and sets the title.
curl -sf $URL -d tab=2 --data-urlencode "sql=INSERT INTO foo.bar (y) VALUES (TRUE); SELECT y, 1 + 2 AS z FROM foo.bar" > $HTML_FILE
grep -F '<button type="submit" name="goto" value="2">INSERT INTO foo.bar (y) VALUES...</button>' $HTML_FILE
grep -F '<span class="status">1 row (' $HTML_FILE
grep -F '<tr><th>Y<span class="type">BOOLEAN</span></th><th>Z<span class="type">SMALLINT</span></th></tr></thead><tbody><tr><td>TRUE</td><td>3</td></tr>' $HTML_FILE
curl -sf $URL -d tab=2 --data-urlencode "sql=INSERT INTO foo.bar (y) VALUES (FALSE)" > $HTML_FILE
grep -F '<span class="status">INSERT 1 (' $HTML_FILE

# Switching tabs saves the SQL, but doesn't run either tab. The last result of
# the tab is shown.
curl -sf $URL -d tab=2 --data-urlencode "sql=SELECT * FROM foo.bar" -d goto=1 -D - -o /dev/null | grep -F 'Location: /'
curl -sf $URL > $HTML_FILE
grep -F '<input type="hidden" name="tab" value="1">' $HTML_FILE
grep -F '>SELECT * FROM &quot;PUBLIC&quot;.&quot;my &lt;t&gt;&quot;</textarea>' $HTML_FILE
grep -F '<td>a&amp;b</td>' $HTML_FILE
curl -sf $URL -d tab=1 --data-urlencode 'sql=SELECT * FROM "PUBLIC"."my <t>"' -d goto=2 -o /dev/null
curl -sf $URL > $HTML_FILE
grep -F '>SELECT * FROM foo.bar</textarea>' $HTML_FILE
grep -F '<span class="status">INSERT 1 (' $HTML_FILE
curl -sf $URL -d tab=1 --data-urlencode 'sql=SELECT * FROM "PUBLIC"."my <t>"' > $HTML_FILE
grep -F '<tr><th></th><th>X<span class="type">INTEGER</span></th><th>S<span class="type">CHARACTER VARYING(10)</span></th></tr>' $HTML_FILE
grep -F '<tr><td class="row-actions"></td><td>1</td><td>a&amp;b</td></tr><tr><td class="row-actions"></td><td class="null">NULL</td><td class="null">NULL</td></tr>' $HTML_FILE
grep -F '<span class="status">2 rows (' $HTML_FILE
echo 'SELECT COUNT(*) FROM foo.bar;' | $VSQL cli $VSQL_FILE | grep -E '^ *2$'

# An error is shown on the page.
curl -sf $URL -d tab=1 --data-urlencode "sql=SELECT * FROM nope" > $HTML_FILE
grep -F 'no such table' $HTML_FILE
grep -F '<span class="status">Error (' $HTML_FILE

# The tabs (and which is active) are restored when the file is opened again,
# but not their results.
kill $APP_PID
wait $APP_PID || true
$VSQL app -p $PORT $VSQL_FILE &
APP_PID=$!
sleep 2
curl -sf $URL > $HTML_FILE
grep -F '<span class="tab active"><button type="submit" name="goto" value="1">SELECT * FROM nope</button>' $HTML_FILE
grep -F '<span class="tab"><button type="submit" name="goto" value="2">INSERT INTO foo.bar (y) VALUES...</button>' $HTML_FILE
grep -F 'Run to see the result.' $HTML_FILE

# Going home doesn't change the SQL of the other tabs.
curl -sf $URL -d tab=1 --data-urlencode 'sql=SELECT * FROM nope' -d goto=0 -o /dev/null
curl -sf $URL | grep -F '<span class="tab home active">'
curl -sf $URL -d tab=0 -d goto=1 -o /dev/null
curl -sf $URL | grep -F '>SELECT * FROM nope</textarea>'

# Closing the active tab activates the first tab, and closing the last tab
# activates the home tab.
curl -sf $URL -d tab=1 -d sql= -d close=1 -o /dev/null
curl -sf $URL > $HTML_FILE
grep -F '<span class="tab active"><button type="submit" name="goto" value="2">' $HTML_FILE
if grep -F 'value="1">' $HTML_FILE; then exit 1; fi
curl -sf $URL -d tab=2 -d sql= -d close=2 -o /dev/null
curl -sf $URL > $HTML_FILE
grep -F '<span class="tab home active">' $HTML_FILE
if grep -F 'name="close"' $HTML_FILE; then exit 1; fi

# The rows of SELECT * FROM a table (which may have a WHERE, ORDER BY, etc) can
# be changed. Only a table with a PRIMARY KEY can have rows updated or deleted,
# and a generated column can't be changed.
curl -sf $URL -d tab=0 -d query=PK -o /dev/null
curl -sf $URL -d tab=3 --data-urlencode 'sql=SELECT * FROM pk WHERE id < 10 ORDER BY id' > $HTML_FILE
grep -F '<table class="editable" data-schema="PUBLIC" data-table="PK"><thead><tr><th></th><th>ID' $HTML_FILE
grep -F '<tr data-key="{&quot;ID&quot;:&quot;1&quot;}"><td class="row-actions"><button type="button" class="delete" title="Delete">&times;</button></td><td data-column="ID" title="Double-click to edit">1</td><td data-column="NAME" title="Double-click to edit">a</td><td class="null" data-column="TS" title="Double-click to edit">NULL</td><td>2</td><td class="null" data-column="B" title="Double-click to edit" data-boolean>UNKNOWN</td></tr>' $HTML_FILE
grep -F '<td><input data-column="TS" placeholder="DEFAULT" spellcheck="false"></td><td class="null">generated</td><td><select data-column="B"><option value="">DEFAULT</option><option>UNKNOWN</option><option>TRUE</option><option>FALSE</option></select></td></tr></tfoot>' $HTML_FILE
for sql in 'SELECT id, name, ts, g, b FROM pk' 'SELECT * FROM pk UNION SELECT * FROM pk' 'SELECT * FROM pk AS p' 'SELECT * FROM (SELECT * FROM pk) AS p' 'SELECT * FROM pk; SELECT * FROM pk'; do
	if curl -sf $URL -d tab=3 --data-urlencode "sql=$sql" | grep -F 'class="editable"'; then exit 1; fi
done
curl -sf $URL -d tab=3 --data-urlencode 'sql=SELECT * FROM pk WHERE id < 10 ORDER BY id' -o /dev/null

# A change is shown to be confirmed, it's not run until it is. Then the SQL of
# the tab is run again.
curl -sf $URL -d tab=3 -d change=update -d schema=PUBLIC -d table=PK -d key:ID=1 --data-urlencode "value:NAME=it's" > $HTML_FILE
grep -F '<input type="hidden" name="confirm" value="UPDATE PUBLIC.PK SET NAME = &#39;it&#39;&#39;s&#39; WHERE ID = 1"><pre class="sql">' $HTML_FILE
echo 'SELECT name FROM pk;' | $VSQL cli $VSQL_FILE | grep -E '^a *$'
curl -sf $URL -d tab=3 --data-urlencode "confirm=UPDATE PUBLIC.PK SET NAME = 'it''s' WHERE ID = 1" -D - -o /dev/null | grep -F 'Location: /'
curl -sf $URL > $HTML_FILE
grep -F '<span class="status">UPDATE 1, 1 row (' $HTML_FILE
grep -F '<td data-column="NAME" title="Double-click to edit">it&#39;s</td>' $HTML_FILE

# Values are CAST to the type of the column, a datetime can be entered like it's
# shown. A value can be set to NULL.
curl -sf $URL -d tab=3 -d change=update -d schema=PUBLIC -d table=PK -d key:ID=1 -d value:TS=2020-01-02T03:04:05 | grep -F 'value="UPDATE PUBLIC.PK SET TS = CAST(&#39;2020-01-02 03:04:05&#39; AS TIMESTAMP(0) WITHOUT TIME ZONE) WHERE ID = 1"'
curl -sf $URL -d tab=3 -d change=update -d schema=PUBLIC -d table=PK -d key:ID=1 -d null:NAME=1 | grep -F 'value="UPDATE PUBLIC.PK SET NAME = NULL WHERE ID = 1"'
curl -sf $URL -d tab=3 -d change=update -d schema=PUBLIC -d table=PK -d key:ID=1 -d value:G=5 | grep -F '<p class="error">no value to update</p>'

# An insert isn't confirmed, it's run straight away. A column that's not
# entered isn't inserted, so it gets its DEFAULT. If it fails, the values that
# were entered are kept.
curl -sf $URL -d tab=3 -d change=insert -d schema=PUBLIC -d table=PK -d value:ID=2 -d value:NAME=b -d value:B=TRUE -D - -o /dev/null | grep -F 'Location: /'
curl -sf $URL | grep -F '<span class="status">INSERT 1, 2 rows ('
echo 'SELECT name, g, b FROM pk WHERE id = 2;' | $VSQL cli $VSQL_FILE | grep -E '^b +\| +4 \| TRUE$'
curl -sf $URL -d tab=3 -d change=insert -d schema=PUBLIC -d table=PK | grep -F '<p class="error">enter a value for at least one column</p>'
curl -sf $URL -d tab=3 -d change=insert -d schema=PUBLIC -d table=PK -d value:ID=1 --data-urlencode 'value:NAME=<keep>' -d value:B=FALSE > $HTML_FILE
grep -F '<p class="error">violates unique constraint: PRIMARY KEY' $HTML_FILE
grep -F '<input data-column="ID" value="1" placeholder="DEFAULT"' $HTML_FILE
grep -F '<input data-column="NAME" value="&lt;keep&gt;" placeholder="DEFAULT"' $HTML_FILE
grep -F '<select data-column="B"><option value="">DEFAULT</option><option>UNKNOWN</option><option>TRUE</option><option selected>FALSE</option></select>' $HTML_FILE
grep -F '<span class="status">INSERT 1, 2 rows (' $HTML_FILE

curl -sf $URL -d tab=3 -d change=delete -d schema=PUBLIC -d table=PK -d key:ID=2 | grep -F 'value="DELETE FROM PUBLIC.PK WHERE ID = 2"'
curl -sf $URL -d tab=3 --data-urlencode "confirm=DELETE FROM PUBLIC.PK WHERE ID = 2" -o /dev/null
curl -sf $URL | grep -F '<span class="status">DELETE 1, 1 row ('

# A change must be to exactly one row, otherwise it's rolled back. An error is
# shown with the last result.
curl -sf $URL -d tab=3 --data-urlencode "confirm=DELETE FROM PUBLIC.PK WHERE ID = 2" > $HTML_FILE
grep -F '<p class="error">DELETE 0: the change must be to 1 row, so it was rolled back</p>' $HTML_FILE
grep -F '<span class="status">DELETE 1, 1 row (' $HTML_FILE
curl -sf $URL -d tab=3 --data-urlencode "confirm=UPDATE PUBLIC.PK SET NAME = 'x'" -o /dev/null
echo 'SELECT COUNT(*) FROM pk;' | $VSQL cli $VSQL_FILE | grep -E '^ *1$'

if curl -sf "${URL}nope"; then exit 1; fi
