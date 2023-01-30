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

	mut db := vsql.open(cmd.args[0]) or { return err }

	for {
		print('vsql> ')
		query := os.get_line()

		if query != '' {
			start := time.ticks()
			result := db.query(query) or { return err }

			mut total_rows := 0
			for row in result {
				for column in result.columns {
					print('${column.name}: ${row.get_string(column.name)} ')
				}
				total_rows++
			}

			if total_rows > 0 {
				println('')
			}

			println('${total_rows} ${vsql.pluralize(total_rows, 'row')} (${time.ticks() - start} ms)')
		}

		println('')
	}
}
