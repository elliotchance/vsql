module main

import cli
import vsql

fn register_server_command(mut cmd cli.Command) {
	mut server_cmd := cli.Command{
		name:          'server'
		description:   'Run as a server for PostgreSQL clients'
		usage:         '<file>'
		required_args: 1
		execute:       server_command
	}
	server_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'verbose'
		abbrev:      'v'
		description: 'Verbose (show all messages in and out of the server)'
	})
	server_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'host'
		description: 'Address to listen on (default 127.0.0.1, use 0.0.0.0 or :: for every interface)'
	})
	server_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'port'
		abbrev:      'p'
		description: 'Port number (default 3210)'
	})
	cmd.add_command(server_cmd)
}

fn server_command(cmd cli.Command) ! {
	print_version()

	mut port := cmd.flags.get_int('port') or { 0 }
	if port == 0 {
		port = 3210
	}

	mut server := vsql.new_server(vsql.ServerOptions{
		host:                cmd.flags.get_string('host') or { '' }
		db_file:             cmd.args[0]
		port:                port
		verbose:             cmd.flags.get_bool('verbose') or { false }
		select_without_from: true
	})

	server.listen()!
	println('ready on ${server.address()!}')
	server.serve()!
}
