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
	server_cmd.add_flag(cli.Flag{
		flag: .bool
		name: 'verbose'
		abbrev: 'v'
		description: 'Verbose (show all messages in and out of the server)'
	})
	server_cmd.add_flag(cli.Flag{
		flag: .int
		name: 'port'
		abbrev: 'p'
		description: 'Port number (default 3210)'
	})
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
	mut port := cmd.flags.get_int('port') or { 0 }
	if port == 0 {
		port = 3210
	}

	// TODO(elliotchance): Make port a CLI option.
	mut server := vsql.new_server(vsql.ServerOptions{
		db_file: cmd.args[0]
		port: port
		verbose: cmd.flags.get_bool('verbose') or { false }
	})

	server.start() or { panic(err) }
}
