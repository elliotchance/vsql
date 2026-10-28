module main

import cli
import os
import vsql

fn register_module_command(mut cmd cli.Command) {
	mut module_cmd := cli.Command{
		name:          'module'
		usage:         '<file>'
		required_args: 1
		description:   'Compile an SQL-client module (LANGUAGE C) into a C header and source file next to it'
		execute:       module_command
	}
	cmd.add_command(module_cmd)
}

fn module_command(cmd cli.Command) ! {
	path := cmd.args[0]
	base := path.all_before_last('.')
	name := os.file_name(base)
	compiled := vsql.compile_module(os.read_file(path)!, name) or {
		print_error('Error', err)
		exit(1)
	}

	os.write_file(base + '.h', compiled.header)!
	os.write_file(base + '.c', compiled.source)!
}
