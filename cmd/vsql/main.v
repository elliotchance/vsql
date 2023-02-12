module main

import cli
import os

fn main() {
	mut cmd := cli.Command{
		name: 'vsql'
		description: 'vsql is a single-file or PostgeSQL-compatible SQL database written in V.\nhttps://github.com/elliotchance/vsql'
		execute: unknown_command
	}

	register_bench_command(mut cmd)
	register_cli_command(mut cmd)
	register_in_command(mut cmd)
	register_out_command(mut cmd)
	register_server_command(mut cmd)
	register_version_command(mut cmd)

	cmd.setup()
	cmd.parse(os.args)
}

fn unknown_command(_ cli.Command) ! {
	println('unknown or missing command, see "vsql help"')
	exit(1)
}
