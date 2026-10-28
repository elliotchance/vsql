#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
HTML_FILE="$(mktemp)" || exit 1
PORT=3297
URL="http://127.0.0.1:$PORT/"

echo "CREATE TABLE \"my <t>\" (x INT, s VARCHAR(10)); INSERT INTO \"my <t>\" (x, s) VALUES (1, 'a&b'), (NULL, NULL); CREATE SCHEMA foo; CREATE TABLE foo.bar (y BOOLEAN);" | $VSQL in $VSQL_FILE

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
grep -F '<summary>PUBLIC <span class="count">1 table</span></summary>' $HTML_FILE
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
grep -F '<tr><th>X<span class="type">INTEGER</span></th><th>S<span class="type">CHARACTER VARYING(10)</span></th></tr>' $HTML_FILE
grep -F '<tr><td>1</td><td>a&amp;b</td></tr><tr><td class="null">NULL</td><td class="null">NULL</td></tr>' $HTML_FILE
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

if curl -sf "${URL}nope"; then exit 1; fi
