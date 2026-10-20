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
	cmd.add_command(bench_cmd)
}

fn bench_command(cmd cli.Command) ! {
	print_version()

	mut file := cmd.flags.get_string('file') or { '' }
	if file == '' {
		file = 'bench.vsql'
	}

	if file != ':memory:' {
		for path in [file, '${file}.wal', '${file}.session'] {
			if os.exists(path) {
				os.rm(path)!
			}
		}
	}

	mut conn := vsql.open(file)!

	mut benchmark := vsql.new_benchmark(conn)
	accounts := cmd.flags.get_int('accounts') or { 0 }
	if accounts > 0 {
		benchmark.account_rows = accounts
	}
	duration := cmd.flags.get_int('duration') or { 0 }
	if duration > 0 {
		benchmark.run_for = duration * time.second
	}
	benchmark.start()!
}
