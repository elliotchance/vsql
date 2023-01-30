module main

import cli

fn register_version_command(mut cmd cli.Command) {
	mut version_cmd := cli.Command{
		name: 'version'
		description: 'Show version'
		execute: version_command
	}
	cmd.add_command(version_cmd)
}

fn version_command(cmd cli.Command) ? {
	print_version()
}

fn print_version() {
	// This constant is replaced at build time. See ci.yml.
	version := 'MISSING_VERSION'

	// Be careful not to use the constant value again as it will be replaced.
	if version.contains('MISSING') {
		println('no version information available')
	} else {
		println('vsql ${version}')
	}
}
