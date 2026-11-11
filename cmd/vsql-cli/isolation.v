module main

import cli
import vsql

// add_isolation_flag adds -isolation, which is the isolation level of a
// transaction that doesn't have one (see ConnectionOptions.isolation_level).
fn add_isolation_flag(mut cmd cli.Command, default_level string) {
	cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'isolation'
		description: "The isolation level of a transaction that doesn't have one: read-uncommitted, read-committed, repeatable-read or serializable (default ${default_level})"
	})
}

// isolation_flag is the level of -isolation, or default_level.
fn isolation_flag(cmd cli.Command, default_level string) !vsql.IsolationLevel {
	mut level := cmd.flags.get_string('isolation') or { '' }
	if level == '' {
		level = default_level
	}
	return match level {
		'read-uncommitted' { .read_uncommitted }
		'read-committed' { .read_committed }
		'repeatable-read' { .repeatable_read }
		'serializable' { .serializable }
		else {
			error('unknown isolation level: ${level} (expected read-uncommitted, read-committed, repeatable-read or serializable)')
		}
	}
}
