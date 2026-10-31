// The ALTER_TABLE tab of "vsql app", see docs/cli.rst.
module app

import json2
import strings
import vsql

// AlterTablePayload is the PAYLOAD (JSON) of an ALTER_TABLE tab. It has the
// table as it was when the tab was opened (each column's original), which the
// ALTER TABLE statements are built from by app_alter_table.js.
struct AlterTablePayload {
	// table is the table as it's used in SQL.
	table string
	// primary_key_name is the PRIMARY KEY to drop when it's changed, or empty
	// if there's no PRIMARY KEY. primary_key are its columns, in order. Names
	// are as they're used in SQL.
	primary_key_name string
	primary_key      []string
	columns          []AlterColumn
	// removed are the columns that were removed (their originals).
	removed []OriginalColumn
}

// AlterColumn is a column as it's edited (like a column of a CREATE_TABLE
// tab). A new column (added by app_alter_table.js) has no original.
struct AlterColumn {
	name           string
	typ            string @[json: 'type']
	not_null       bool
	primary_key    bool
	auto_increment bool
	default_value  string @[json: 'default']
	original       OriginalColumn
}

struct OriginalColumn {
	// sql_name is the name as it's used in SQL.
	sql_name       string
	not_null       bool
	primary_key    bool
	auto_increment bool
	generated      bool
	default_value  string @[json: 'default']
	// not_null_name is the constraint to drop to remove its NOT NULL, or empty
	// if it can't be removed.
	not_null_name string
}

// alter_table_payload is the payload of a new ALTER_TABLE tab for a table (see
// find_edit_table).
fn (a &App) alter_table_payload(mut conn vsql.Connection, catalog string, schema string, name string) !string {
	table := a.find_edit_table(mut conn, catalog, schema, name)!
	set_catalog(mut conn, if catalog == '' { a.catalog_names[0] } else { catalog })!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}

	mut defaults := map[string]string{}
	mut identity := map[string]bool{}
	mut not_null := map[string]bool{}
	mut stmt := conn.prepare('SELECT column_name, column_default, is_nullable, is_identity FROM information_schema.columns WHERE table_schema = ? AND table_name = ?')!
	for row in stmt.query({
		'?1': vsql.new_varchar_value(schema)
		'?2': vsql.new_varchar_value(name)
	})! {
		column := row.get_string('COLUMN_NAME')!
		defaults[column] = if row.get_null('COLUMN_DEFAULT')! {
			''
		} else {
			row.get_string('COLUMN_DEFAULT')!
		}
		identity[column] = row.get_string('IS_IDENTITY')! == 'YES'
		not_null[column] = row.get_string('IS_NULLABLE')! == 'NO'
	}

	// A NOT NULL is a CHECK constraint of the table, such as "A IS NOT NULL".
	mut primary_key_name := ''
	mut checks := map[string]bool{}
	stmt = conn.prepare('SELECT constraint_name, constraint_type FROM information_schema.table_constraints WHERE table_schema = ? AND table_name = ?')!
	for row in stmt.query({
		'?1': vsql.new_varchar_value(schema)
		'?2': vsql.new_varchar_value(name)
	})! {
		constraint_name := row.get_string('CONSTRAINT_NAME')!
		match row.get_string('CONSTRAINT_TYPE')! {
			'PRIMARY KEY' { primary_key_name = sql_constraint_name(constraint_name) }
			'CHECK' { checks[constraint_name] = true }
			else {}
		}
	}
	mut not_null_names := map[string]string{}
	stmt = conn.prepare('SELECT constraint_name, check_clause FROM information_schema.check_constraints WHERE constraint_schema = ?')!
	for row in stmt.query({
		'?1': vsql.new_varchar_value(schema)
	})! {
		constraint_name := row.get_string('CONSTRAINT_NAME')!
		if constraint_name in checks {
			not_null_names[row.get_string('CHECK_CLAUSE')!] = sql_constraint_name(constraint_name)
		}
	}

	mut columns := []AlterColumn{}
	for column in table.columns {
		sql_name := column.sql_name()
		original := OriginalColumn{
			sql_name:       sql_name
			not_null:       not_null[column.name]
			primary_key:    column.name in table.primary_key
			auto_increment: identity[column.name]
			generated:      column.generated && !identity[column.name]
			default_value:  defaults[column.name]
			not_null_name:  not_null_names['${sql_name} IS NOT NULL'] or { '' }
		}
		columns << AlterColumn{
			name:           column.name
			typ:            vsql.Type{
				...column.typ
				not_null: false
			}.str()
			not_null:       original.not_null
			primary_key:    original.primary_key
			auto_increment: original.auto_increment
			default_value:  original.default_value
			original:       original
		}
	}

	return json2.encode(AlterTablePayload{
		table:            table.sql_name()
		primary_key_name: primary_key_name
		primary_key:      table.primary_key.map(vsql.Identifier{
			sub_entity_name: it
		}.str())
		columns:          columns
	})
}

fn sql_constraint_name(name string) string {
	return vsql.Identifier{
		entity_name: name
	}.str()
}

// write_alter_table is an ALTER_TABLE tab, after the tabs. It's like a
// CREATE_TABLE tab (see write_create_table), with the ALTER TABLE statements
// (which can't be edited) at the top. Alter table runs them in a transaction,
// closes the tab and queries the table in a new tab. The form is closed.
fn write_alter_table(mut sb strings.Builder, tab Tab, result TabResult) {
	sb.write_string('<div class="create-table alter-table" data-payload="${html_escape(tab.payload)}">')
	sb.write_string('<input type="hidden" name="payload" value="${html_escape(tab.payload)}"><input type="hidden" name="alter_sql" value="">')
	sb.write_string('<pre class="sql create-sql"></pre>')
	if result.error != '' {
		sb.write_string('<p class="error">${html_escape(result.error)}</p>')
	}
	sb.write_string('<table class="columns"><thead><tr><th>Name</th><th>Type</th><th>NOT NULL</th><th>PRIMARY KEY</th><th>Auto increment</th><th>DEFAULT</th><th></th></tr></thead><tbody></tbody></table>')
	sb.write_string('<button type="button" class="add-column">+ Add column</button>')
	sb.write_string('<div class="create-actions"><button type="submit" name="alter_table" value="1" class="create">Alter table</button>')
	sb.write_string('<button type="button" class="cancel-create">Cancel</button></div></div></form>')
	sb.write_string('<dialog class="confirm discard"><p>Discard these changes?</p><div class="create-actions">')
	sb.write_string('<button type="submit" form="app" name="close" value="${tab.id}" class="delete">Discard</button>')
	sb.write_string('<button type="button" class="keep">Keep editing</button></div></dialog>')
}
