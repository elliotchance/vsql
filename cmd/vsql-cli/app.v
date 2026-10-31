module main

import app
import cli

fn register_app_command(mut cmd cli.Command) {
	mut app_cmd := cli.Command{
		name:        'app'
		description: 'Run a web server to browse the tables and their rows'
		usage:       '[<file> ...]'
		execute:     app_command
	}
	app_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'host'
		description: 'Address to listen on (default 127.0.0.1, use 0.0.0.0 or :: for every interface)'
	})
	app_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'port'
		abbrev:      'p'
		description: 'Port number (default 3211)'
	})
	cmd.add_command(app_cmd)
}

// default_app_file is opened when no file is given, in the current directory.
const default_app_file = 'app.vsql'

fn app_command(cmd cli.Command) ! {
	print_version()

	paths := if cmd.args.len == 0 { [default_app_file] } else { cmd.args }

	mut host := cmd.flags.get_string('host') or { '' }
	if host == '' {
		host = '127.0.0.1'
	}
	mut port := cmd.flags.get_int('port') or { 0 }
	if port == 0 {
		port = 3211
	}

	app.serve(paths, host, port)!
}
