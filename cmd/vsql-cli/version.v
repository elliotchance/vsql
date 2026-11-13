module main

import cli
import vsql

fn register_version_command(mut cmd cli.Command) {
	mut version_cmd := cli.Command{
		name:        'version'
		description: 'Show version'
		execute:     version_command
	}
	version_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'verbose'
		abbrev:      'v'
		description: 'Show how vsql was built, as shell variables'
	})
	cmd.add_command(version_cmd)
}

fn version_command(cmd cli.Command) ! {
	if !(cmd.flags.get_bool('verbose') or { false }) {
		print_version()
		return
	}

	// These are the same as the BUILD items that SQL_IMPLEMENTATION_INFO will
	// have.
	commit := vsql.build_commit()
	mut lines := [
		shell_variable('BUILD VERSION', if vsql.build_version() == '' {
			none
		} else {
			vsql.build_version()
		}),
		shell_variable('BUILD COMMIT', if commit == '' { none } else { commit }),
		shell_variable('BUILD DATE', vsql.build_date()),
		shell_variable('BUILD V VERSION', vsql.build_v_version()),
		shell_variable('BUILD V COMMIT', vsql.build_v_commit()),
		shell_variable('BUILD C COMPILER', vsql.build_c_compiler()),
	]
	lines.sort()
	for line in lines {
		println(line)
	}
}

// shell_variable is an SQL-implementation information item as a line that a
// POSIX shell can run, such as "VSQL_BUILD_DATE='2026-11-12'". The variable is
// empty when the item has no value.
fn shell_variable(name string, value ?string) string {
	variable := 'VSQL_' + name.replace(' ', '_')
	if v := value {
		return "${variable}='" + v.replace("'", "'\\''") + "'"
	}

	return '${variable}='
}

fn print_version() {
	version := vsql.build_version()
	if version == '' {
		println('no version information available')
	} else {
		println('vsql ${version} ${vsql.build_date()}')
	}
}
