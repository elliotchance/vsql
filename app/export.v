// Exporting a result, table or schema from "vsql app", see docs/cli.rst.
module app

import json2
import strings
import vsql

// Download is a file that's exported, see export.
struct Download {
	filename     string
	content_type string
	body         string
}

// export is the file for an export posted as JSON, the format (csv, json or
// sql) then what's exported:
//
//   ["csv"]                           the last result of the tab
//   ["sql", catalog, schema]          a schema, with its tables and rows
//   ["csv", catalog, schema, table]   the rows (or sql, with CREATE TABLE)
//
// A result is exported by running its SQL again, in a transaction that's
// rolled back, so anything else it does (such as an INSERT before the SELECT)
// isn't done again. A sequence is the exception, it's never rolled back.
fn (a &App) export(mut conn vsql.Connection, tab_id int, value string) !Download {
	args := json2.decode[[]string](value)!
	if args.len !in [1, 3, 4] {
		return error('bad export: ${value}')
	}
	format := args[0]

	if args.len == 1 {
		query := rlock a.results {
			(a.results[tab_id] or { TabResult{} }).query
		}
		if query == '' {
			return error('there is no result to export')
		}
		conn.query('START TRANSACTION')!
		defer {
			conn.query('ROLLBACK') or {}
		}
		mut result := vsql.Result{}
		for stmt in vsql.split_statements(query) {
			result = conn.query(stmt)!
		}
		return export_rows(result, 'result', format)!
	}

	catalog, schema := args[1], args[2]
	if catalog !in a.catalog_names {
		return error('no such catalog: ${catalog}')
	}
	set_catalog(mut conn, catalog)!
	defer {
		set_catalog(mut conn, a.catalog_names[0]) or {}
	}
	if args.len == 3 {
		if format != 'sql' {
			return error('a schema can only be exported as SQL')
		}
		mut sb := strings.new_builder(4096)
		conn.dump(mut sb, schema: schema)!
		return Download{'${schema}.sql', 'application/sql; charset=utf-8', sb.str()}
	}

	table := args[3]
	if format == 'sql' {
		mut sb := strings.new_builder(4096)
		conn.dump(mut sb, schema: schema, table: table)!
		return Download{'${table}.sql', 'application/sql; charset=utf-8', sb.str()}
	}
	result := conn.query('SELECT * FROM ${vsql.Identifier{
		schema_name: schema
		entity_name: table
	}}')!
	return export_rows(result, table, format)!
}

// export_rows is the rows of a result as CSV (with a header of the column
// names) or JSON (an array with an object for each row). A NULL is empty in
// CSV, and null in JSON.
fn export_rows(result vsql.Result, name string, format string) !Download {
	if result.columns.len == 0 {
		return error('there are no rows to export')
	}
	names := result.columns.map(it.name.sub_entity_name)
	mut sb := strings.new_builder(4096)
	match format {
		'csv' {
			sb.write_string(names.map(csv_field).join(',') + '\r\n')
			for row in result {
				mut fields := []string{}
				for column in result.columns {
					value := row.get_column(column)!
					fields << if value.is_null { '' } else { csv_field(value.str()) }
				}
				sb.write_string(fields.join(',') + '\r\n')
			}
			return Download{'${name}.csv', 'text/csv; charset=utf-8', sb.str()}
		}
		'json' {
			sb.write_string('[')
			mut first := true
			for row in result {
				sb.write_string(if first { '\n  {' } else { ',\n  {' })
				first = false
				for i, column in result.columns {
					if i > 0 {
						sb.write_string(', ')
					}
					sb.write_string('${json2.encode(names[i])}: ${json_value(row.get_column(column)!)}')
				}
				sb.write_string('}')
			}
			sb.write_string(if first { ']\n' } else { '\n]\n' })
			return Download{'${name}.json', 'application/json; charset=utf-8', sb.str()}
		}
		else {
			return error('unknown format: ${format}')
		}
	}
}

// csv_field is quoted if it has a comma, quote or new line, or white space at
// either end.
fn csv_field(s string) string {
	if s.contains_any(',"\r\n') || s != s.trim_space() {
		return '"${s.replace('"', '""')}"'
	}

	return s
}

// json_value is a number for an integer, true or false for a BOOLEAN (UNKNOWN
// is null) and a string for anything else, as it's shown in a result. A
// DECIMAL or floating-point number is a string so that it's exact.
fn json_value(value vsql.Value) string {
	if value.is_null {
		return 'null'
	}
	match value.typ.typ {
		.is_smallint, .is_integer, .is_bigint {
			return value.str()
		}
		.is_boolean {
			return match value.str() {
				'TRUE' { 'true' }
				'FALSE' { 'false' }
				else { 'null' }
			}
		}
		else {
			return json2.encode(value.str())
		}
	}
}
