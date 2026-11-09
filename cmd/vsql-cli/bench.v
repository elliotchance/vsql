module main

import cli
import os
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
		flag:        .int
		name:        'processes'
		description: 'Number of processes that run transactions on the file at the same time, then the balances are checked (default 1)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'worker'
		description: 'Run transactions on a file that -processes made, and print how many were committed'
	})
	cmd.add_command(bench_cmd)
}

fn bench_command(cmd cli.Command) ! {
	mut file := cmd.flags.get_string('file') or { '' }
	if file == '' {
		file = 'bench.vsql'
	}
	accounts := cmd.flags.get_int('accounts') or { 0 }
	duration := cmd.flags.get_int('duration') or { 0 }
	processes := cmd.flags.get_int('processes') or { 0 }

	// A worker only prints its result, which the process that started it reads
	// (see run_processes).
	if cmd.flags.get_bool('worker') or { false } {
		mut benchmark := new_benchmark(vsql.open(file)!)
		benchmark.set_options(accounts, duration)
		benchmark.run_worker()!
		return
	}

	print_version()

	if processes > 1 && file == ':memory:' {
		return error("-processes needs a file, since processes can't share :memory:")
	}

	if file != ':memory:' {
		for path in [file, '${file}.wal', '${file}.session'] {
			if os.exists(path) {
				os.rm(path)!
			}
		}
	}

	mut conn := vsql.open(file)!

	mut benchmark := new_benchmark(conn)
	benchmark.set_options(accounts, duration)
	if processes > 1 {
		benchmark.run_processes(file, processes)!
		return
	}
	benchmark.start()!
}
