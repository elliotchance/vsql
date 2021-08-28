module main

import cli
import os
import time
import vsql

fn main() {
	mut cmd := cli.Command{
		name: 'vsql'
		description: 'vsql is a single-file SQL database written in V'
		execute: cli_command
	}

	mut server_cmd := cli.Command{
		name: 'server'
		description: 'Run as a server for PostgreSQL clients'
		usage: '<file>'
		required_args: 1
		execute: server_command
	}
	cmd.add_command(server_cmd)

	cmd.setup()
	cmd.parse(os.args)
}

fn cli_command(cmd cli.Command) ? {
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

fn server_command(cmd cli.Command) {
	// TODO(elliotchance): Make port a CLI option.
	mut server := vsql.new_server(cmd.args[0], 3210)

	server.start() or { panic(err) }
}
