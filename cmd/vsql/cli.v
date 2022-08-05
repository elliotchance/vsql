module main

import cli
import os
import time
import vsql

fn register_cli_command(mut cmd cli.Command) {
	mut cli_cmd := cli.Command{
		name: 'cli'
		usage: '<file>'
		required_args: 1
		description: 'Run SQL in a vsql file'
		execute: cli_command
	}
	cmd.add_command(cli_cmd)
}

fn cli_command(cmd cli.Command) ? {
	print_version()

	mut db := vsql.open(cmd.args[0])?

	for {
		print('vsql> ')
		query := os.get_line()

		if query != '' {
			start := time.ticks()
			result := db.query(query)?
			for row in result {
				for column in result.columns {
					print('$column.name: ${row.get_string(column.name)} ')
				}
			}

			if result.rows.len > 0 {
				println('')
			}

			println('$result.rows.len ${vsql.pluralize(result.rows.len, 'row')} (${time.ticks() - start} ms)')
		}

		println('')
	}
}
