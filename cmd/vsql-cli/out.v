module main

import cli
import os
import vsql

fn register_out_command(mut cmd cli.Command) {
	mut out_cmd := cli.Command{
		name:          'out'
		usage:         '<file>'
		required_args: 1
		description:   'Export schema and data'
		execute:       out_command
	}

	out_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'create-public-schema'
		description: 'Include "CREATE SCHEMA PUBLIC"'
	})

	cmd.add_command(out_cmd)
}

fn out_command(cmd cli.Command) ! {
	mut db := vsql.open(cmd.args[0])!
	mut stdout := os.stdout()
	db.dump(mut stdout,
		create_public_schema: cmd.flags.get_bool('create-public-schema') or { false }
	)!
}
