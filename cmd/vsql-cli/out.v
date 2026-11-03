module main

import cli
import json2
import os
import strings
import vsql

fn register_out_command(mut cmd cli.Command) {
	mut out_cmd := cli.Command{
		name:          'out'
		usage:         '<file>'
		required_args: 1
		description:   'Export schema and data, or the result of a query'
		execute:       out_command
	}

	out_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'format'
		description: 'sql (default), or csv, tsv or json with -query'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'file'
		description: 'Write to this file instead of stdout'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .string_array
		name:        'include'
		description: 'Only objects that match schema.name, which can have wildcards (default *.*)'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .string_array
		name:        'exclude'
		description: 'Leave out objects that match schema.name, which can have wildcards'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'query'
		description: 'Export the result of this query, with P1, P2, etc for each "?"'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'no-header'
		description: 'Leave out the line of column names of csv or tsv'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'null'
		description: 'Write NULL as this in csv or tsv (default is empty)'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'no-transaction'
		description: 'Leave out START TRANSACTION and COMMIT around sql'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'create-public-schema'
		description: 'Include "CREATE SCHEMA PUBLIC"'
	})

	out_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'compat'
		description: 'Write sql for vsql (default), sqlite3, mysql or postgresql'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'data-only'
		description: 'Only the rows and the positions of sequences of sql'
	})
	out_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'schema-only'
		description: 'Only the definitions of sql, without any rows'
	})

	cmd.add_command(out_cmd)
}

// OutOptions are the flags of "vsql out".
struct OutOptions {
	format               string
	file                 string
	include              []string
	exclude              []string
	query                string
	no_header            bool
	null_value           string
	no_transaction       bool
	create_public_schema bool
	compat               string
	data_only            bool
	schema_only          bool
}

// check is an error for the flags that can't be used together.
fn (o OutOptions) check() ! {
	if o.format !in ['sql', 'csv', 'tsv', 'json'] {
		return error('-format must be sql, csv, tsv or json')
	}
	if o.query == '' {
		if o.format != 'sql' {
			return error("-format ${o.format} needs -query, a table can be exported with -query 'TABLE foo'")
		}
	} else {
		if o.format == 'sql' {
			return error('-query needs -format csv, tsv or json')
		}
		if o.include.len > 0 || o.exclude.len > 0 {
			return error('-query cannot be used with -include or -exclude')
		}
	}
	if o.no_header && o.format !in ['csv', 'tsv'] {
		return error('-no-header needs -format csv or tsv')
	}
	if o.null_value != '' && o.format !in ['csv', 'tsv'] {
		return error('-null needs -format csv or tsv')
	}
	if o.no_transaction && o.format != 'sql' {
		return error('-no-transaction needs -format sql')
	}
	if o.create_public_schema && o.format != 'sql' {
		return error('-create-public-schema needs -format sql')
	}
	if o.compat !in ['', 'vsql', 'sqlite3', 'mysql', 'postgresql'] {
		return error('-compat must be vsql, sqlite3, mysql or postgresql')
	}
	if o.compat != '' && o.format != 'sql' {
		return error('-compat needs -format sql')
	}
	if o.create_public_schema && o.compat !in ['', 'vsql'] {
		return error('-create-public-schema cannot be used with -compat ${o.compat}')
	}
	if o.data_only && o.schema_only {
		return error('-data-only cannot be used with -schema-only')
	}
	if o.data_only && o.format != 'sql' {
		return error('-data-only needs -format sql')
	}
	if o.schema_only && o.format != 'sql' {
		return error('-schema-only needs -format sql')
	}
}

fn out_command(cmd cli.Command) ! {
	// Anything after the file isn't parsed as a flag, so it would be ignored.
	if cmd.args.len > 1 {
		return error('flags must be before the file, found: ${cmd.args[1..].join(' ')}')
	}

	format := cmd.flags.get_string('format') or { '' }
	query := cmd.flags.get_string('query') or { '' }
	options := OutOptions{
		format:               if format == '' { 'sql' } else { format }
		file:                 cmd.flags.get_string('file') or { '' }
		include:              cmd.flags.get_strings('include') or { [] }
		exclude:              cmd.flags.get_strings('exclude') or { [] }
		query:                query
		no_header:            cmd.flags.get_bool('no-header') or { false }
		null_value:           cmd.flags.get_string('null') or { '' }
		no_transaction:       cmd.flags.get_bool('no-transaction') or { false }
		create_public_schema: cmd.flags.get_bool('create-public-schema') or { false }
		compat:               cmd.flags.get_string('compat') or { '' }
		data_only:            cmd.flags.get_bool('data-only') or { false }
		schema_only:          cmd.flags.get_bool('schema-only') or { false }
	}
	options.check()!

	mut db := vsql.open(cmd.args[0])!
	if options.file == '' {
		mut stdout := os.stdout()
		options.write(mut db, mut stdout)!
		return
	}

	// The file is only replaced once it's all written, so a failed export doesn't
	// leave part of one behind.
	temp := '${options.file}.${os.getpid()}.tmp'
	mut file := os.create(temp)!
	options.write(mut db, mut file) or {
		file.close()
		os.rm(temp) or {}
		return err
	}
	file.close()
	os.mv(temp, options.file)!
}

// write is the export.
fn (o OutOptions) write(mut db vsql.Connection, mut w os.File) ! {
	if o.format == 'sql' {
		db.dump(mut w,
			create_public_schema: o.create_public_schema
			include:              o.include
			exclude:              o.exclude
			transaction:          !o.no_transaction
			compat:               match o.compat {
				'sqlite3' { vsql.DumpCompat.sqlite3 }
				'mysql' { vsql.DumpCompat.mysql }
				'postgresql' { vsql.DumpCompat.postgresql }
				else { vsql.DumpCompat.vsql }
			}
			data_only:            o.data_only
			schema_only:          o.schema_only
		)!
		return
	}

	result := run_out_query(mut db, o.query)!
	names := result.columns.map(it.name.sub_entity_name)
	mut sb := strings.new_builder(4096)
	match o.format {
		'csv' { write_delimited(mut sb, result, names, `,`, !o.no_header, o.null_value)! }
		'tsv' { write_delimited(mut sb, result, names, `\t`, !o.no_header, o.null_value)! }
		else { write_json(mut sb, result, names)! }
	}
	w.write(sb)!
}

// run_out_query runs a query, each "?" gets its value from the environment: P1
// for the first, P2 for the second and so on. A value is a string, or NULL if
// it's \N.
fn run_out_query(mut db vsql.Connection, query string) !vsql.Result {
	if vsql.split_statements(query).len != 1 {
		return error('-query must be a single query')
	}
	mut prepared := db.prepare(query)!
	function, _ := prepared.command_function()
	if function != 'SELECT CURSOR' {
		return error('-query must be a query, not ${function}')
	}

	mut params := map[string]vsql.Value{}
	mut missing := []string{}
	for i in 1 .. prepared.dynamic_parameter_count() + 1 {
		value := os.getenv_opt('P${i}') or {
			missing << 'P${i}'
			continue
		}
		params['?${i}'] = if value == '\\N' {
			vsql.new_null_value(.is_varchar)
		} else {
			vsql.new_varchar_value(value)
		}
	}
	if missing.len > 0 {
		return error('environment variables are not set: ${missing.join(', ')}')
	}

	return prepared.query(params)!
}

// write_delimited writes CSV or TSV (RFC 4180, with \r\n for CSV and \n for TSV).
// A string that's the same as null_value (or empty) is quoted to tell it apart
// from NULL.
fn write_delimited(mut sb strings.Builder, result vsql.Result, names []string, delimiter u8, header bool, null_value string) ! {
	eol := if delimiter == `,` { '\r\n' } else { '\n' }
	sep := delimiter.ascii_str()
	if header {
		sb.write_string(names.map(delimited_field(it, sep, null_value)).join(sep) + eol)
	}
	for row in result {
		mut fields := []string{}
		for column in result.columns {
			value := row.get_column(column)!
			fields << if value.is_null {
				null_value
			} else {
				delimited_field(value.str(), sep, null_value)
			}
		}
		sb.write_string(fields.join(sep) + eol)
	}
}

// delimited_field is quoted if it's empty or the same as null_value, or has the
// delimiter, a quote or new line, or white space at either end.
fn delimited_field(s string, delimiter string, null_value string) string {
	if s == '' || s == null_value || s.contains_any('${delimiter}"\r\n') || s != s.trim_space() {
		return '"${s.replace('"', '""')}"'
	}

	return s
}

// write_json writes an array with an object for each row, and each value on its
// own line.
fn write_json(mut sb strings.Builder, result vsql.Result, names []string) ! {
	mut rows := []string{}
	for row in result {
		mut fields := []string{}
		for i, column in result.columns {
			fields << '    ${json2.encode(names[i])}: ${json_value(row.get_column(column)!)}'
		}
		rows << '  {\n${fields.join(',\n')}\n  }'
	}
	sb.write_string(if rows.len == 0 { '[]\n' } else { '[\n${rows.join(',\n')}\n]\n' })
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
