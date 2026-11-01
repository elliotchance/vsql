// Changing the rows of a result in "vsql app", see docs/cli.rst.
module app

import json2
import net.urllib
import vsql

// EditTable is a table whose rows can be inserted, updated and deleted from a
// result, see editable_table.
struct EditTable {
	// catalog is empty when there is only one file, so it's left out of the
	// SQL like the sidebar.
	catalog string
	schema  string
	name    string
	columns []EditColumn
	// primary_key is empty if the table has no PRIMARY KEY, then its rows can't
	// be changed, because there's no way to say which row to change.
	primary_key []string
}

struct EditColumn {
	name string
	typ  vsql.Type
	// generated is true if a value can't be assigned to the column, because it
	// is a generated column or an identity column that's GENERATED ALWAYS.
	generated bool
	// required is true if a value must be given, because it's NOT NULL without
	// a DEFAULT.
	required bool
}

fn (t EditTable) sql_name() string {
	return vsql.Identifier{
		catalog_name: t.catalog
		schema_name:  t.schema
		entity_name:  t.name
	}.str()
}

fn (t EditTable) column(name string) !EditColumn {
	return t.columns.filter(it.name == name)[0] or { error('no such column: ${name}') }
}

fn (c EditColumn) sql_name() string {
	return vsql.Identifier{
		sub_entity_name: c.name
	}.str()
}

// find_edit_table finds a table in a catalog (or the first catalog if it's
// empty).
fn (a &App) find_edit_table(mut conn vsql.Connection, catalog string, schema string, name string) !EditTable {
	if catalog != '' && catalog !in a.catalog_names {
		return error('no such catalog: ${catalog}')
	}
	catalog_name := if catalog == '' { a.catalog_names[0] } else { catalog }
	set_catalog(mut conn, catalog_name)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}

	mut cat := conn.catalog()
	table := cat.schema_tables(schema)!.filter(it.name.entity_name == name)[0] or {
		return error('no such table: ${schema}.${name}')
	}

	mut generated := map[string]bool{}
	mut required := map[string]bool{}
	mut stmt := conn.prepare('SELECT column_name, is_nullable, column_default, identity_generation, is_generated FROM information_schema.columns WHERE table_schema = ? AND table_name = ?')!
	for row in stmt.query({
		'?1': vsql.new_varchar_value(schema)
		'?2': vsql.new_varchar_value(name)
	})! {
		generated[row.get_string('COLUMN_NAME')!] = row.get_string('IDENTITY_GENERATION')! == 'ALWAYS'
			|| row.get_string('IS_GENERATED')! == 'ALWAYS'
		required[row.get_string('COLUMN_NAME')!] = row.get_string('IS_NULLABLE')! == 'NO'
			&& row.get_null('COLUMN_DEFAULT')! && row.get_null('IDENTITY_GENERATION')!
	}

	mut columns := []EditColumn{}
	for column in table.columns {
		columns << EditColumn{column.name.sub_entity_name, column.typ, generated[column.name.sub_entity_name], required[column.name.sub_entity_name]}
	}

	return EditTable{if a.catalog_names.len == 1 { '' } else { catalog_name }, schema, name, columns, table.primary_key}
}

// editable_table returns the table that the rows of a result belong to, if the
// SQL is a single SELECT * FROM a table (see is_select_star) with a PRIMARY KEY.
// The result columns must be every column of the table, in order.
fn (a &App) editable_table(mut conn vsql.Connection, query_text string, result vsql.Result) ?EditTable {
	stmts := vsql.split_statements(query_text)
	if stmts.len != 1 || !is_select_star(stmts[0]) || result.columns.len == 0 {
		return none
	}

	first := result.columns[0].name
	if first.schema_name == '' || first.entity_name == '' {
		return none
	}
	for column in result.columns {
		if column.name.catalog_name != first.catalog_name
			|| column.name.schema_name != first.schema_name
			|| column.name.entity_name != first.entity_name || column.name.custom_id != '' {
			return none
		}
	}

	table := a.find_edit_table(mut conn, first.catalog_name, first.schema_name, first.entity_name) or {
		return none
	}
	if table.primary_key.len == 0
		|| table.columns.map(it.name) != result.columns.map(it.name.sub_entity_name) {
		return none
	}

	return table
}

// is_select_star is true if query is SELECT * FROM a table, optionally followed
// by WHERE, ORDER BY, OFFSET or FETCH, so that each row of the result is a row
// of the table.
fn is_select_star(query string) bool {
	words := top_level_words(query)
	if words.len < 4 || words[..3] != ['SELECT', '*', 'FROM'] {
		return false
	}

	// The table name is one to three names separated by dots.
	mut i := 4
	for i + 1 < words.len && words[i] == '.' {
		i += 2
	}
	if !is_name(words[3]) || (i < words.len && words[i] !in ['WHERE', 'ORDER', 'OFFSET', 'FETCH']) {
		return false
	}

	return !words[i..].any(it in ['UNION', 'EXCEPT', 'INTERSECT', 'JOIN', 'GROUP', 'HAVING', 'WINDOW',
		','])
}

fn is_name(word string) bool {
	return word.starts_with('"') || word[0].is_letter() || word[0] == `_`
}

// top_level_words splits query into upper case words, quoted names and strings,
// and symbols, except for anything inside parentheses (other than the opening
// parenthesis), comments and semicolons.
fn top_level_words(query string) []string {
	mut words := []string{}
	mut depth := 0
	mut i := 0
	for i < query.len {
		c := query[i]
		if c == `'` || c == `"` {
			// A quote inside is doubled.
			mut j := i + 1
			for j < query.len {
				if query[j] == c {
					if j + 1 < query.len && query[j + 1] == c {
						j += 2
						continue
					}
					break
				}
				j++
			}
			if depth == 0 {
				words << query[i..if j < query.len { j + 1 } else { j }]
			}
			i = j + 1
		} else if query[i..].starts_with('--') {
			for i < query.len && query[i] != `\n` {
				i++
			}
		} else if query[i..].starts_with('/*') {
			end := query.index_after('*/', i + 2) or { query.len }
			i = end + 2
		} else if c.is_letter() || c == `_` {
			mut j := i
			for j < query.len && (query[j].is_letter() || query[j].is_digit() || query[j] == `_`) {
				j++
			}
			if depth == 0 {
				words << query[i..j].to_upper()
			}
			i = j
		} else {
			if c == `(` {
				if depth == 0 {
					words << '('
				}
				depth++
			} else if c == `)` {
				depth--
			} else if depth == 0 && !c.is_space() && c != `;` {
				words << c.ascii_str()
			}
			i++
		}
	}

	return words
}

// change_form is the fields of a change posted from an editable result, without
// the number of the change that's before each name (such as "0:change").
fn change_form(form urllib.Values, i int) urllib.Values {
	prefix := '${i}:'
	mut change := urllib.new_values()
	for value in form.data {
		if value.key.starts_with(prefix) {
			change.add(value.key[prefix.len..], value.value)
		}
	}

	return change
}

// build_change returns the INSERT, UPDATE or DELETE for a change posted from an
// editable result. A value is posted as "value:<column>" (or "null:<column>" for NULL, or
// "default:<column>" for its DEFAULT) and the primary key of the row as
// "key:<column>".
fn build_change(table EditTable, form urllib.Values) !string {
	kind := form.get('change') or { '' }
	match kind {
		'insert' {
			mut names := []string{}
			mut values := []string{}
			for column in table.columns {
				if value := change_value(column, form) {
					names << column.sql_name()
					values << value
				}
			}
			// Every column gets its DEFAULT (or is generated).
			if names.len == 0 {
				names << table.columns[0].sql_name()
				values << 'DEFAULT'
			}

			return 'INSERT INTO ${table.sql_name()} (${names.join(', ')}) VALUES (${values.join(', ')})'
		}
		'update' {
			mut sets := []string{}
			for column in table.columns {
				if value := change_value(column, form) {
					sets << '${column.sql_name()} = ${value}'
				}
			}
			if sets.len == 0 {
				return error('no value to update')
			}

			return 'UPDATE ${table.sql_name()} SET ${sets.join(', ')} WHERE ${change_where(table, form)!}'
		}
		'delete' {
			return 'DELETE FROM ${table.sql_name()} WHERE ${change_where(table, form)!}'
		}
		else {
			return error('unknown change: ${kind}')
		}
	}
}

// change_value is the literal for a column that's posted, if it is. A
// generated column can't be changed.
fn change_value(column EditColumn, form urllib.Values) ?string {
	if column.generated {
		return none
	}
	if _ := form.get('null:${column.name}') {
		return 'NULL'
	}
	if _ := form.get('default:${column.name}') {
		return 'DEFAULT'
	}
	if value := form.get('value:${column.name}') {
		return sql_literal(column.typ, value)
	}

	return none
}

// change_where is the condition for the row with the primary key that's
// posted.
fn change_where(table EditTable, form urllib.Values) !string {
	if table.primary_key.len == 0 {
		return error('${table.sql_name()} has no PRIMARY KEY')
	}

	mut conditions := []string{}
	for name in table.primary_key {
		column := table.column(name)!
		value := form.get('key:${name}') or { return error('no value for ${name}') }
		conditions << '${column.sql_name()} = ${sql_literal(column.typ, value)}'
	}

	return conditions.join(' AND ')
}

// sql_literal is value (as it's entered, or as it's shown in the result) as a
// literal of typ. It's a CAST if there's no simpler literal.
fn sql_literal(typ vsql.Type, value string) string {
	match typ.typ {
		.is_varchar, .is_character {
			return quote_string(value)
		}
		.is_smallint, .is_integer, .is_bigint, .is_decimal, .is_numeric, .is_real,
		.is_double_precision {
			if value != '' && value.bytes().all(it.is_digit() || it in [`.`, `e`, `E`, `+`, `-`]) {
				return value
			}
		}
		.is_boolean {
			if value.to_upper() in ['TRUE', 'FALSE', 'UNKNOWN'] {
				return value.to_upper()
			}
		}
		.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
		.is_timestamp_without_time_zone, .is_timestamp_with_time_zone {
			return 'CAST(${quote_string(castable_datetime(value))} AS ${vsql.Type{
				...typ
				not_null: false
			}})'
		}
	}

	return 'CAST(${quote_string(value)} AS ${vsql.Type{
		...typ
		not_null: false
	}})'
}

fn quote_string(s string) string {
	return "'${s.replace("'", "''")}'"
}

// castable_datetime changes a datetime as it's shown in a result (such as
// 2020-01-02T03:04:05.000000+0500) into a string that can be CAST back (such as
// 2020-01-02 03:04:05.000000+05:00).
fn castable_datetime(s string) string {
	mut t := s
	if t.len > 10 && t[10] == `T` {
		t = t[..10] + ' ' + t[11..]
	}
	if t.len > 5 && t[t.len - 5] in [`+`, `-`] && t[t.len - 4..].bytes().all(it.is_digit()) {
		t = t[..t.len - 2] + ':' + t[t.len - 2..]
	}

	return t
}

// run_changes runs every change in one transaction. Each must change exactly
// one row, otherwise all of them are rolled back.
fn run_changes(mut conn vsql.Connection, queries []string) ! {
	conn.query('START TRANSACTION')!
	for query in queries {
		result := conn.query(query) or {
			conn.query('ROLLBACK') or {}
			return error('${query}: ${err.msg()}: nothing was saved')
		}
		if !result.msg.ends_with(' 1') {
			conn.query('ROLLBACK')!
			return error('${query}: changed ${result.msg}, it must change 1 row: nothing was saved')
		}
	}
	conn.query('COMMIT')!
}

// row_key is the primary key of a row of an editable result, as JSON for the
// data-key of the row (see app_edit.js).
fn row_key(table EditTable, row vsql.Row) !string {
	mut key := map[string]string{}
	for name in table.primary_key {
		key[name] = row.get_string(name)!
	}

	return json2.encode(key, escape_unicode: true, time_as_unix: true)
}
