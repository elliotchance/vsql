module main

import cli
import io
import os
import vsql

fn register_in_command(mut cmd cli.Command) {
	mut in_cmd := cli.Command{
		name:          'in'
		usage:         '<file>'
		required_args: 1
		description:   'Import schema and data'
		execute:       in_command
	}

	in_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'continue-on-error'
		description: 'Continue when errors occur'
	})

	in_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'verbose'
		abbrev:      'v'
		description: 'Show result of each command'
	})

	cmd.add_command(in_cmd)
}

fn in_command(cmd cli.Command) ! {
	mut db := vsql.open(cmd.args[0]) or { return err }
	script := io.read_all(reader: os.stdin())!.bytestr()
	continue_on_error := cmd.flags.get_bool('continue-on-error') or { false }
	verbose := cmd.flags.get_bool('verbose') or { false }

	// Keep running stats for the end.
	mut stmt_count := 0
	mut error_count := 0
	timer := vsql.start_timer()

	for stmt in vsql.split_statements(script) {
		stmt_count++
		result := db.query(stmt) or {
			println(err)
			error_count++
			if continue_on_error {
				continue
			}
			break
		}

		if result.msg != '' && verbose {
			println(result.msg)
		}
	}

	println('${error_count} errors, ${stmt_count} statements, ${timer.elapsed()}')

	if error_count > 0 {
		exit(1)
	}
}
