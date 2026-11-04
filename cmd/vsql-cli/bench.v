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
		flag:        .int
		name:        'connections'
		description: 'Number of connections running transactions at the same time, each in its own thread (default 1)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'scale'
		description: 'Number of rows in the BRANCHES table, and a tenth of the rows in the TELLERS table (default is the number of connections)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'isolation'
		description: 'Isolation level of the transactions: READ COMMITTED, REPEATABLE READ or SERIALIZABLE (default SERIALIZABLE)'
	})
	cmd.add_command(bench_cmd)
}

fn bench_command(cmd cli.Command) ! {
	print_version()

	mut file := cmd.flags.get_string('file') or { '' }
	if file == '' {
		file = 'bench.vsql'
	}

	// The isolation level can also be written in lowercase, or with
	// underscores, such as read_committed.
	isolation := (cmd.flags.get_string('isolation') or { '' }).to_upper().replace('_', ' ')
	if isolation == 'READ UNCOMMITTED' {
		return error('READ UNCOMMITTED transactions are READ ONLY, so they cannot run the benchmark')
	}
	if isolation !in ['', 'READ COMMITTED', 'REPEATABLE READ', 'SERIALIZABLE'] {
		return error('unknown isolation level: ${isolation}')
	}

	if file != ':memory:' {
		for path in [file, '${file}.wal', '${file}.session', '${file}.isolation'] {
			if os.exists(path) {
				os.rm(path)!
			}
		}
	}

	// Connections in the same process must share the mutex, see
	// ConnectionOptions.
	options := vsql.default_connection_options()
	mut conn := vsql.open_database(file, options)!

	mut benchmark := new_benchmark(conn)
	benchmark.file = file
	benchmark.options = options
	connections := cmd.flags.get_int('connections') or { 0 }
	if connections > 0 {
		benchmark.connections = connections
	}

	// Each connection to :memory: has its own database.
	if benchmark.connections > 1 && file == ':memory:' {
		return error('-connections can only be used with a file')
	}

	// Every transaction updates one of the branches, so with fewer branches
	// than connections the benchmark mostly measures the transactions that
	// conflict with each other. Like pgbench, the scale should be at least the
	// number of connections.
	mut scale := cmd.flags.get_int('scale') or { 0 }
	if scale <= 0 {
		scale = benchmark.connections
	}
	benchmark.branch_rows = scale
	benchmark.teller_rows = 10 * scale

	accounts := cmd.flags.get_int('accounts') or { 0 }
	if accounts > 0 {
		benchmark.account_rows = accounts
	}
	duration := cmd.flags.get_int('duration') or { 0 }
	if duration > 0 {
		benchmark.run_for = duration * time.second
	}
	benchmark.isolation_level = isolation
	benchmark.start()!
}
