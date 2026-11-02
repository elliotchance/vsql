// The CREATE_TABLE tab of "vsql app", see docs/cli.rst.
module app

import json2
import strings

// new_table_payload is the PAYLOAD (JSON) of a new CREATE_TABLE tab for a
// schema (as it's used in SQL, such as FOO), which can be changed on the tab.
// The tab runs in the file of the schema, so the file isn't in the SQL. It starts with an auto increment ID column as the PRIMARY KEY. The payload is
// changed by app_create_table.js, the server doesn't need to read it.
fn new_table_payload(schema string) string {
	return '{"schema":${json2.encode(schema)},"name":"","columns":[{"name":"ID","type":"INTEGER","not_null":false,"primary_key":true,"auto_increment":true,"default":""}]}'
}

// write_create_table is a CREATE_TABLE tab, after the tabs. The schema, table name,
// columns and the CREATE TABLE (which can't be edited) are built from the
// payload by app_create_table.js. Create table runs the SQL, closes the tab and
// queries the table (created_table) in a new tab. Cancel closes the tab once
// it's confirmed. The form is closed.
fn write_create_table(mut sb strings.Builder, tab Tab, result TabResult) {
	sb.write_string('<div class="create-table" data-payload="${html_escape(tab.payload)}">')
	sb.write_string('<input type="hidden" name="payload" value="${html_escape(tab.payload)}"><input type="hidden" name="create_sql" value=""><input type="hidden" name="created_table" value="">')
	sb.write_string('<pre class="sql create-sql"></pre>')
	if result.error != '' {
		sb.write_string('<p class="error">${html_escape(result.error)}</p>')
	}
	sb.write_string('<label class="table-schema">Schema <input spellcheck="false" placeholder="SCHEMA"></label>')
	sb.write_string('<label class="table-name">Table name <input spellcheck="false" placeholder="NAME" autofocus></label>')
	sb.write_string('<table class="columns"><thead><tr><th>Name</th><th>Type</th><th>NOT NULL</th><th>PRIMARY KEY</th><th>Auto increment</th><th>DEFAULT</th><th></th></tr></thead><tbody></tbody></table>')
	sb.write_string('<button type="button" class="add-column">+ Add column</button>')
	sb.write_string('<div class="create-actions"><button type="submit" name="create_table" value="1" class="create">Create table</button>')
	sb.write_string('<button type="button" class="cancel-create">Cancel</button></div></div></form>')
	sb.write_string('<dialog class="confirm discard"><p>Discard this table?</p><div class="create-actions">')
	sb.write_string('<button type="submit" form="app" name="close" value="${html_escape(tab.ref())}" class="delete">Discard</button>')
	sb.write_string('<button type="button" class="keep">Keep editing</button></div></dialog>')
}
