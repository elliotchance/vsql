module main

import cli
import time
import vsql

fn register_bench_command(mut cmd cli.Command) {
	mut bench_cmd := cli.Command{
		name:        'bench'
		description: 'Run benchmark'
		execute:     bench_command
	}
	bench_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'memory'
		description: 'Run the benchmark in memory. This is the default, unless -file is used'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'file'
		description: 'Run the benchmark on disk, in this file. The tpc-b and tpc-b-setup suites create the tables, so the file must not already have them'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'size'
		description: 'Multiplies the number of rows (and other actions) of the benchmark, such as 10 for 1,000,000 accounts (default 1)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'suite'
		description: 'The suite to run:\ntpc-b-setup: create the tables and insert the rows\ntpc-b-oltp: run transactions on a -file from tpc-b-setup\ntpc-b-check: check the rows of a -file from tpc-b-setup\ntpc-b: all three (the default)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'duration'
		description: 'Seconds to run transactions for (default 60)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'isolation'
		description: 'Isolation level of the transactions: read-committed, repeatable-read or serializable (default serializable)'
	})
	cmd.add_command(bench_cmd)
}

fn bench_command(cmd cli.Command) ! {
	memory := cmd.flags.get_bool('memory') or { false }
	mut file := cmd.flags.get_string('file') or { '' }
	if memory && file != '' {
		return error('-memory and -file can not be used together')
	}
	if file == '' {
		file = ':memory:'
	}

	suite := cmd.flags.get_string('suite') or { '' }
	if suite !in ['', 'tpc-b', 'tpc-b-setup', 'tpc-b-oltp', 'tpc-b-check'] {
		return error('unknown suite: ${suite} (expected tpc-b, tpc-b-setup, tpc-b-oltp or tpc-b-check)')
	}
	all := suite in ['', 'tpc-b']
	setup := all || suite == 'tpc-b-setup'
	oltp := all || suite == 'tpc-b-oltp'
	check := all || suite == 'tpc-b-check'

	// tpc-b-oltp and tpc-b-check need the rows that tpc-b-setup inserted, which
	// a new in-memory database wouldn't have.
	if !setup && file == ':memory:' {
		return error('-suite ${suite} needs a -file that -suite tpc-b-setup created')
	}

	isolation := cmd.flags.get_string('isolation') or { '' }
	if isolation == 'read-uncommitted' {
		return error('READ UNCOMMITTED transactions are READ ONLY, so they cannot run the benchmark')
	}
	if isolation !in ['', 'read-committed', 'repeatable-read', 'serializable'] {
		return error('unknown isolation level: ${isolation} (expected read-committed, repeatable-read or serializable)')
	}

	size := cmd.flags.get_int('size') or { 0 }
	if size < 0 {
		return error('-size must be at least 1')
	}
	if !setup && size > 0 {
		return error('-size can not be used with -suite ${suite}, which uses the size of the -file')
	}

	mut conn := vsql.open(file)!

	mut benchmark := new_benchmark(conn, if size > 0 { size } else { 1 })
	duration := cmd.flags.get_int('duration') or { 0 }
	if duration > 0 {
		benchmark.run_for = duration * time.second
	}
	benchmark.isolation_level = isolation.to_upper().replace('-', ' ')
	if !setup {
		benchmark.read_size()!
	}

	// The output is one "name=value" line for each setting and result, so it
	// can be read by people, and by a shell (with source). The "#" lines are
	// headings (and comments to a shell).
	println('# vsql bench')
	print_value('version', vsql.version())
	print_value('version_date', vsql.version_date())
	print_value('suite', if suite == '' { 'tpc-b' } else { suite })
	print_value('file', file)
	print_value('size', benchmark.branch_rows.str())
	if oltp {
		print_value('duration_seconds', int(benchmark.run_for.seconds()).str())
		print_value('isolation', if isolation == '' { 'serializable' } else { isolation })
	}

	if setup {
		benchmark.setup()!
	}
	if oltp {
		benchmark.oltp()!
	}
	if check {
		benchmark.check()!
	}
	benchmark.print_peak_memory()
}
