module main

import cli
import os
import time
import vsql

fn register_cli_command(mut cmd cli.Command) {
	mut cli_cmd := cli.Command{
		name:          'cli'
		usage:         '<file>'
		required_args: 1
		description:   'Run SQL in a vsql file'
		execute:       cli_command
	}
	cmd.add_command(cli_cmd)
}

fn cli_command(cmd cli.Command) ! {
	print_version()
	println('')

	mut db := vsql.open(cmd.args[0])!

	for arg in cmd.args[1..] {
		catalog_name := vsql.catalog_name_from_path(arg)
		options := vsql.default_connection_options()
		db.add_catalog(catalog_name, arg, options)!
	}

	for {
		print('vsql> ')
		os.flush()

		raw_query := os.get_line()

		// When running on Docker, ctrl+C doesn't always get passed through. Also,
		// this provides another text based way to break out of the shell.
		if raw_query.trim_space() == 'exit' {
			break
		}

		if raw_query != '' {
			// TODO: This is a very poor way to handle multiple queries.
			for i, query in raw_query.split(';') {
				if query.trim_space() == '' {
					continue
				}

				start := time.ticks()
				db.clear_warnings()
				result := db.query(query) or {
					print_error('Error', err)
					continue
				}

				for warning in db.warnings {
					print_error('Warning', warning)
				}

				mut total_rows := 0
				for row in result {
					for column in result.columns {
						print('${column.name.sub_entity_name}: ${row.get_string(column.name.sub_entity_name)!} ')
					}
					total_rows++
				}

				if total_rows > 0 {
					println('')
				}

				println('${total_rows} ${vsql.pluralize(total_rows, 'row')} (${time.ticks() - start} ms)')

				if i > 0 {
					println('')
				}
			}
		} else {
			// This means there is no more input and should only occur when the
			// commands are being few through a pipe like:
			//
			//   echo "VALUES CURRENT_CATALOG;" | vsql cli
			break
		}

		println('')
	}
}

fn print_error(prefix string, err IError) {
	if err.code() > 0 {
		sqlstate := vsql.sqlstate_from_int(err.code())
		println('${prefix} ${sqlstate}: ${err.msg()}\n')
	} else {
		println('ERROR: ${err}\n')
	}
}
