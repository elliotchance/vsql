module main

import cli
import os
import vsql

fn register_precompile_command(mut cmd cli.Command) {
	mut precompile_cmd := cli.Command{
		name:          'precompile'
		usage:         '<file>'
		required_args: 1
		description:   'Precompile an embedded SQL C program (such as example.sqc) into a C file next to it'
		execute:       precompile_command
	}
	precompile_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'module'
		description: 'Also write the implied SQL-client module (such as example.mod)'
	})
	cmd.add_command(precompile_cmd)
}

fn precompile_command(cmd cli.Command) ! {
	path := cmd.args[0]
	base := path.all_before_last('.')
	precompiled := vsql.precompile_c(os.read_file(path)!, os.file_name(path)) or {
		print_error('Error', err)
		exit(1)
	}

	os.write_file(base + '.c', precompiled.source)!
	if cmd.flags.get_bool('module')! {
		os.write_file(base + '.mod', precompiled.implied_module)!
	}
}
