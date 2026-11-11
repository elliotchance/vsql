module main

import cli
import os
import time
import vsql

fn register_bench_command(mut cmd cli.Command) {
	mut bench_cmd := cli.Command{
		name:        'bench'
		description: 'Run benchmark'
		execute:     bench_command
	}
	bench_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'file'
		abbrev:      'f'
		description: 'File path that will be deleted and created for the test. You can use :memory: as well (default bench.vsql)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'accounts'
		description: 'Number of rows in the ACCOUNTS table (default 100000)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'duration'
		description: 'Seconds to run transactions for (default 60)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'isolation'
		description: 'Isolation level of the transactions: read-uncommitted, read-committed, repeatable-read or serializable (default serializable)'
	})
	cmd.add_command(bench_cmd)
}

fn bench_command(cmd cli.Command) ! {
	isolation := cmd.flags.get_string('isolation') or { '' }
	if isolation !in ['', 'read-uncommitted', 'read-committed', 'repeatable-read', 'serializable'] {
		return error('unknown isolation level: ${isolation} (expected read-uncommitted, read-committed, repeatable-read or serializable)')
	}

	print_version()

	mut file := cmd.flags.get_string('file') or { '' }
	if file == '' {
		file = 'bench.vsql'
	}

	if file != ':memory:' {
		for path in [file, '${file}.wal', '${file}.session', '${file}.isolation'] {
			if os.exists(path) {
				os.rm(path)!
			}
		}
	}

	mut conn := vsql.open(file)!

	mut benchmark := new_benchmark(conn)
	accounts := cmd.flags.get_int('accounts') or { 0 }
	if accounts > 0 {
		benchmark.account_rows = accounts
	}
	duration := cmd.flags.get_int('duration') or { 0 }
	if duration > 0 {
		benchmark.run_for = duration * time.second
	}
	benchmark.isolation_level = isolation.to_upper().replace('-', ' ')
	benchmark.start()!
}
