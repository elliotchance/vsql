module main

import cli

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
	println(if version := vsql_version() {
		'vsql ${version}'
	} else {
		'no version information available'
	})
}

// vsql_version is the version of the release, such as "v0.33.0 2026-10-26".
// There is no version for a local build.
fn vsql_version() ?string {
	// This constant is replaced at build time. See ci.yml.
	version := 'MISSING_VERSION'

	// Be careful not to use the constant value again as it will be replaced.
	if version.contains('MISSING') {
		return none
	}

	return version
}
