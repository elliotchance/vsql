module main

import cli
import os
import time
import vsql

fn main() {
	mut app := cli.Command{
		name: 'vsql'
		description: 'vsql is a single-file SQL database written in V'
		execute: main_command
	}
	app.setup()
	app.parse(os.args)
}

fn main_command(cmd cli.Command) ? {
	if cmd.args.len != 1 {
		return error('usage: vsql file.vsql')
	}

	mut db := vsql.open(cmd.args[0]) ?
	for {
		print('vsql> ')
		query := os.get_line()

		start := time.ticks()
		result := db.query(query) ?
		for row in result {
			for column in result.columns {
				print('$column: ${row.get_string(column)} ')
			}
		}

		if result.rows.len > 0 {
			println('')
		}

		println('$result.rows.len ${vsql.pluralize(result.rows.len, 'row')} (${time.ticks() - start} ms)')
		println('')
	}
}
