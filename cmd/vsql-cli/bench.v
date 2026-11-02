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
		description: 'Run the benchmark on disk, in this file. The tpc-b, tpc-b-setup and big suites create the tables, so the file must not already have them'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .int
		name:        'size'
		description: 'Multiplies the number of rows (and other actions) of the benchmark:\ntpc-b: such as 10 for 1,000,000 accounts (default 1)\nspeedtest1: most tables have 500 rows for each size (default 10)\nbig: the MiB of values to insert, at least 10 (default 100)'
	})
	bench_cmd.add_flag(cli.Flag{
		flag:        .string
		name:        'suite'
		description: 'The suite to run:\n' +
			'big: insert values of 1 to 10 MiB until they add up to -size MiB, and read them back\n' +
			'speedtest1: the tests of speedtest1 from SQLite\n' +
			'tpc-b: tpc-b-setup, tpc-b-oltp and tpc-b-check, in that order (the default)\n' +
			'tpc-b-check: check the rows of a -file from tpc-b-setup\n' +
			'tpc-b-oltp: run transactions on a -file from tpc-b-setup\n' +
			'tpc-b-setup: create the tables and insert the rows'
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
	bench_cmd.add_flag(cli.Flag{
		flag:        .bool
		name:        'full-fsync'
		description: 'Use F_FULLFSYNC to sync the file on macOS, see ConnectionOptions.full_fsync (default false)'
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
	if suite !in ['', 'tpc-b', 'tpc-b-setup', 'tpc-b-oltp', 'tpc-b-check', 'big', 'speedtest1'] {
		return error('unknown suite: ${suite} (expected tpc-b, tpc-b-setup, tpc-b-oltp, tpc-b-check, big or speedtest1)')
	}
	big := suite == 'big'
	all := suite in ['', 'tpc-b']
	setup := all || suite == 'tpc-b-setup'
	oltp := all || suite == 'tpc-b-oltp'
	check := all || suite == 'tpc-b-check'

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

	if suite == 'speedtest1' {
		if (cmd.flags.get_int('duration') or { 0 }) != 0 {
			return error('-duration can not be used with -suite speedtest1, which runs each test once')
		}
		return speedtest1(file, if size > 0 { size } else { 10 }, isolation)
	}

	// tpc-b-oltp and tpc-b-check need the rows that tpc-b-setup inserted, which
	// a new in-memory database wouldn't have.
	if !setup && !big && file == ':memory:' {
		return error('-suite ${suite} needs a -file that -suite tpc-b-setup created')
	}

	// The largest value of the big suite is 10 MiB, so at least 10 MiB means at
	// least one whole value is always inserted.
	if big && size > 0 && size < 10 {
		return error('-size must be at least 10 (MiB) for -suite big')
	}
	if !setup && !big && size > 0 {
		return error('-size can not be used with -suite ${suite}, which uses the size of the -file')
	}

	mut options := vsql.default_connection_options()
	options.full_fsync = cmd.flags.get_bool('full-fsync') or { false }
	mut conn := vsql.open_database(file, options)!

	mut benchmark := new_benchmark(conn, if size > 0 { size } else { 1 })
	duration := cmd.flags.get_int('duration') or { 0 }
	if duration > 0 {
		benchmark.run_for = duration * time.second
	}
	benchmark.isolation_level = isolation.to_upper().replace('-', ' ')
	if !setup && !big {
		benchmark.read_size()!
	}

	// The output is one "name=value" line for each setting and result, so it
	// can be read by people, and by a shell (with source). The "#" lines are
	// headings (and comments to a shell).
	println('# vsql bench')
	print_value('build_version', vsql.build_version())
	print_value('build_commit', vsql.build_commit())
	print_value('build_date', vsql.build_date())
	print_value('build_v_version', vsql.build_v_version())
	print_value('build_v_commit', vsql.build_v_commit())
	print_value('build_c_compiler', vsql.build_c_compiler())
	print_value('suite', if suite == '' { 'tpc-b' } else { suite })
	print_value('file', file)
	big_mib := if size > 0 { size } else { big_default_mib }
	print_value('size', if big { big_mib.str() } else { benchmark.branch_rows.str() })
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
	if big {
		benchmark.big(big_mib)!
	}
	benchmark.print_peak_memory()
}

// speedtest1 runs -suite speedtest1, with the same "name=value" heading as the
// other suites. Its results are one line for each test, like SQLite's.
fn speedtest1(file string, size int, isolation string) ! {
	mut conn := vsql.open(file)!

	println('# vsql bench')
	print_value('build_version', vsql.build_version())
	print_value('build_commit', vsql.build_commit())
	print_value('build_date', vsql.build_date())
	print_value('build_v_version', vsql.build_v_version())
	print_value('build_v_commit', vsql.build_v_commit())
	print_value('build_c_compiler', vsql.build_c_compiler())
	print_value('suite', 'speedtest1')
	print_value('file', file)
	print_value('size', size.str())
	print_value('isolation', if isolation == '' { 'serializable' } else { isolation })

	println('# speedtest1')
	mut speedtest := Speedtest1{
		conn:            conn
		size:            size
		isolation_level: isolation.to_upper().replace('-', ' ')
	}
	speedtest.start()!
}
