module main

import cli
import vsql

fn register_version_command(mut cmd cli.Command) {
	mut version_cmd := cli.Command{
		name:        'version'
		description: 'Show version'
		execute:     version_command
	}
	cmd.add_command(version_cmd)
}

fn version_command(_ cli.Command) ! {
	print_version()
}

fn print_version() {
	version := vsql.version()
	if version == '' {
		println('no version information available')
	} else {
		println('vsql ${version} ${vsql.version_date()}')
	}
}
