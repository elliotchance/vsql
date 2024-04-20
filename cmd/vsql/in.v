module main

import cli
import os
import vsql

fn register_in_command(mut cmd cli.Command) {
	mut in_cmd := cli.Command{
		name: 'in'
		usage: '<file>'
		required_args: 1
		description: 'Import schema and data'
		execute: in_command
	}

	in_cmd.add_flag(cli.Flag{
		flag: .bool
		name: 'continue-on-error'
		description: 'Continue when errors occur'
	})

	in_cmd.add_flag(cli.Flag{
		flag: .bool
		name: 'verbose'
		abbrev: 'v'
		description: 'Show result of each command'
	})

	cmd.add_command(in_cmd)
}

fn in_command(cmd cli.Command) ! {
	mut db := vsql.open(cmd.args[0]) or { return err }

	mut f := os.stdin()

	// Keep running stats for the end.
	mut stmt_count := 0
	mut error_count := 0
	timer := vsql.start_timer()

	mut stmt := ''
	for !f.eof() {
		mut buf := []u8{len: 100}
		f.read_bytes_with_newline(mut buf) or { return err }

		line := buf.bytestr()
		stmt += line.trim_right('\0 \n;')

		if line.contains(';') {
			result := db.query(stmt) or {
				println(err)
				error_count++
				vsql.Result{}
			}

			if cmd.flags.get_bool('verbose') or { false } {
				for row in result {
					msg := row.get_string('msg') or { '' }
					if msg != '' {
						println(msg)
						break
					}
				}
			}

			stmt_count++
			stmt = ''
		}
	}

	println('${error_count} errors, ${stmt_count} statements, ${timer.elapsed()}')

	if error_count > 0 {
		exit(1)
	}
}
