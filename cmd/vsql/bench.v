module main

import cli
import vsql

fn register_bench_command(mut cmd cli.Command) {
	mut bench_cmd := cli.Command{
		name: 'bench'
		description: 'Run benchmark'
		execute: bench_command
	}
	bench_cmd.add_flag(cli.Flag{
		flag: .string
		name: 'file'
		abbrev: 'f'
		description: 'File path that will be deleted and created for the test. You can use :memory: as well (default bench.vsql)'
	})
	cmd.add_command(bench_cmd)
}

fn bench_command(cmd cli.Command) ? {
	print_version()

	mut file := cmd.flags.get_string('file') or { '' }
	if file == '' {
		file = 'bench.vsql'
	}

	mut conn := vsql.open(':memory:') or { panic('$err') }

	mut benchmark := vsql.new_benchmark(conn)
	benchmark.start() or { panic('$err') }
}
