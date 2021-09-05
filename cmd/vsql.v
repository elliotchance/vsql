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

	mut bench_cmd := cli.Command{
		name: 'bench'
		description: 'Run benchmark'
		execute: bench_command
	}
	cmd.add_command(bench_cmd)

	mut version_cmd := cli.Command{
		name: 'version'
		description: 'Show version'
		execute: version_command
	}
	cmd.add_command(version_cmd)

	cmd.setup()
	cmd.parse(os.args)
}

fn cli_command(cmd cli.Command) ? {
	print_version()

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

fn server_command(cmd cli.Command) ? {
	print_version()

	mut port := cmd.flags.get_int('port') or { 0 }
	if port == 0 {
		port = 3210
	}

	mut server := vsql.new_server(vsql.ServerOptions{
		db_file: cmd.args[0]
		port: port
		verbose: cmd.flags.get_bool('verbose') or { false }
	})

	server.start() or { panic(err) }
}

fn bench_command(cmd cli.Command) ? {
	print_version()

	mut conn := vsql.open('bench.vsql') or { panic('$err') }

	mut benchmark := vsql.new_benchmark(conn)
	benchmark.start() or { panic('$err') }
}

fn print_version() {
	// This constant is replaced at build time. See ci.yml.
	println('vsql MISSING_VERSION')
}

fn version_command(cmd cli.Command) ? {
	print_version()
}
