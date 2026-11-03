module main

import app
import cli
import os
import vsql

fn register_in_command(mut cmd cli.Command) {
	mut in_cmd := cli.Command{
		name:          'in'
		usage:         '<file>'
		required_args: 1
		description:   'Import schema and data'
		execute:       in_command
	}

	in_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'file'
		description: 'Read from this file instead of stdin'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'format'
		description: 'sql, csv, tsv or json (default is the extension of -file, or sql)'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'schema'
		description: 'The current schema for sql, or the schema of -table (default PUBLIC)'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'table'
		description: 'The table to import csv, tsv or json into'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'create-table'
		description: 'Create -table with these column definitions, such as "ID INTEGER, NAME VARCHAR(100)"'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .string_array
		name:        'map'
		description: 'field=column, the other fields are not imported (default is each field to the column with its name)'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'single-transaction'
		description: 'Run a sql file in one transaction, it must not have its own transactions'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'compat'
		description: 'The dialect of a sql file: sqlite3 (default is vsql)'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'ignore-unsupported'
		description: 'Warn about CREATE VIEW, CREATE TRIGGER and CREATE INDEX instead of failing'
	})
	in_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'continue-on-error'
		description: 'Continue when errors occur'
	})

	in_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'verbose'
		abbrev:      'v'
		description: 'Print each statement with its line, and the bytes read of the file'
	})

	cmd.add_command(in_cmd)
}

// in_format is the format of the input, from the extension of its file if it's
// not given.
fn in_format(format string, file string) !string {
	if format !in ['', 'sql', 'csv', 'tsv', 'json'] {
		return error('-format must be sql, csv, tsv or json')
	}
	if format != '' {
		return format
	}
	extension := os.file_ext(file).trim_left('.').to_lower()

	return if extension in ['csv', 'tsv', 'json'] { extension } else { 'sql' }
}

fn in_command(cmd cli.Command) ! {
	file := cmd.flags.get_string('file') or { '' }
	format := in_format(cmd.flags.get_string('format') or { '' }, file)!
	table := cmd.flags.get_string('table') or { '' }
	create_table := cmd.flags.get_string('create-table') or { '' }
	single_transaction := cmd.flags.get_bool('single-transaction') or { false }
	mut mapping := [][]string{}
	for pair in cmd.flags.get_strings('map') or { []string{} } {
		if !pair.contains('=') {
			return error('-map must be field=column: ${pair}')
		}
		mapping << [pair.all_before_last('='), pair.all_after_last('=')]
	}
	compat := cmd.flags.get_string('compat') or { '' }
	if compat !in ['', 'vsql', 'sqlite3'] {
		return error('-compat must be vsql or sqlite3')
	}
	if format != 'sql' && compat != '' {
		return error('-compat is for sql')
	}
	if format == 'sql' && (table != '' || create_table != '' || mapping.len > 0) {
		return error('-table, -create-table and -map are for csv, tsv or json')
	}
	if format != 'sql' && single_transaction {
		return error('-single-transaction is for sql, ${format} is always in one transaction')
	}
	if format != 'sql' && table == '' {
		return error('-table is needed for ${format}')
	}

	// The database is checked before waiting for stdin.
	mut db := vsql.open(cmd.args[0]) or { return err }
	db.close()
	mut input := if file != '' { os.open(file)! } else { os.stdin() }
	total := if file != '' { i64(os.file_size(file)) } else { i64(-1) }

	succeeded := app.import_database(cmd.args[0], mut input, total, app.ImportOptions{
		format:             format
		schema:             cmd.flags.get_string('schema') or { '' }
		table:              table
		create_table:       create_table
		mapping:            mapping
		continue_on_error:  cmd.flags.get_bool('continue-on-error') or { false }
		single_transaction: single_transaction
		compat:             if compat == 'vsql' { '' } else { compat }
		ignore_unsupported: cmd.flags.get_bool('ignore-unsupported') or { false }
		verbose:            cmd.flags.get_bool('verbose') or { false }
	})!

	if !succeeded {
		exit(1)
	}
}
