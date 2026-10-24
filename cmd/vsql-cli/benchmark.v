// benchmark.v contains functionality to benchmark the performance of vsql. This is
// useful as a local tool and provides insights into changes for performance
// between vsql versions. The test itself is inspired/copied from pgbench.
//
// Usage:
//
//   vsql bench
//
// See https://github.com/elliotchance/vsql/blob/main/docs/benchmark.rst

module main

import rand
import time
import vsql

struct Benchmark {
mut:
	conn         &vsql.Connection
	account_rows int
	teller_rows  int
	branch_rows  int
	run_for      time.Duration
	// isolation_level is used to start each transaction, unless it's empty.
	isolation_level string
	// connections run transactions at the same time, each in its own thread.
	connections int
	file        string
	options     vsql.ConnectionOptions
}

// BenchmarkWorker is one of the connections running transactions.
struct BenchmarkWorker {
mut:
	b         Benchmark
	committed int
	failed    int
}

fn new_benchmark(conn &vsql.Connection) Benchmark {
	return Benchmark{
		account_rows: 100000
		teller_rows:  10
		branch_rows:  1
		run_for:      time.minute
		conn:         conn
		connections:  1
	}
}

fn (mut b Benchmark) start() ! {
	println('${b.account_rows} accounts, ${b.teller_rows} tellers, ${b.branch_rows} branches, ${b.connections} connections')

	b.conn.query('CREATE TABLE accounts ( aid INT, abalance INT, PRIMARY KEY ( aid ) ) ')!

	mut t := vsql.start_timer()
	for aid in 1 .. b.account_rows + 1 {
		b.conn.query('INSERT INTO accounts (aid, abalance) VALUES (${aid}, 0)')!
	}
	b.print_stat('INSERT', b.account_rows, 'rows', t.elapsed())

	b.conn.query('CREATE TABLE tellers ( tid INT, tbalance INT, PRIMARY KEY ( tid ) ) ')!
	for tid in 1 .. b.teller_rows + 1 {
		b.conn.query('INSERT INTO tellers (tid, tbalance) VALUES (${tid}, 0)')!
	}

	b.conn.query('CREATE TABLE branches ( bid INT, bbalance INT, PRIMARY KEY ( bid ) ) ')!
	for bid in 1 .. b.branch_rows + 1 {
		b.conn.query('INSERT INTO branches (bid, bbalance) VALUES (${bid}, 0)')!
	}

	// TODO(elliotchance): This should have a PRIMARY KEY when we support
	//  multiple columns.
	b.conn.query('CREATE TABLE history ( tid INT, bid INT, aid INT, delta INT, mtime VARCHAR(30) ) ')!

	t = vsql.start_timer()

	b.conn.query('SELECT abalance FROM accounts WHERE abalance = 0')!
	b.print_stat('SELECT', b.account_rows, 'rows', t.elapsed())

	mut workers := []&BenchmarkWorker{}
	for i in 0 .. b.connections {
		mut worker := &BenchmarkWorker{
			b: b
		}
		if i > 0 {
			worker.b.conn = vsql.open_database(b.file, b.options)!
		}
		workers << worker
	}

	t = vsql.start_timer()
	mut threads := []thread !{}
	for mut worker in workers {
		threads << spawn worker.run()
	}
	for th in threads {
		th.wait()!
	}
	elapsed := t.elapsed()

	mut committed := 0
	mut failed := 0
	for worker in workers {
		committed += worker.committed
		failed += worker.failed
	}

	mut name := 'TPC-B (sort of'
	if b.isolation_level != '' {
		name += ', ${b.isolation_level}'
	}
	if b.connections > 1 {
		name += ', ${b.connections} connections'
	}
	name += ')'
	b.print_stat(name, committed, 'transactions', elapsed)
	if failed > 0 {
		b.print_stat('40001 serialization failures', failed, 'transactions', elapsed)
	}
}

fn (mut b Benchmark) print_stat(name string, n int, unit string, elapsed time.Duration) {
	println('${name}: ${n} ${unit} in ${elapsed.seconds():.3f} (${n / elapsed.seconds():.3f} ${unit}/s)')
}

fn (mut b Benchmark) run_transaction() ! {
	aid := b.random(1, b.account_rows)
	bid := b.random(1, b.branch_rows)
	tid := b.random(1, b.teller_rows)
	delta := b.random(-5000, 5000)

	if b.isolation_level == '' {
		b.conn.query('START TRANSACTION')!
	} else {
		b.conn.query('START TRANSACTION ISOLATION LEVEL ${b.isolation_level}')!
	}

	b.conn.query('UPDATE accounts SET abalance = abalance + ${delta} WHERE aid = ${aid}')!
	b.conn.query('SELECT abalance FROM accounts WHERE aid = ${aid}')!
	b.conn.query('UPDATE tellers SET tbalance = tbalance + ${delta} WHERE tid = ${tid}')!
	b.conn.query('UPDATE branches SET bbalance = bbalance + ${delta} WHERE bid = ${bid}')!

	// TODO(elliotchance): Should use CURRENT_TIMESTAMP once supported.
	//
	// time.now() is not called inside the string because the V3 compiler
	// generates invalid C for that.
	now := time.now()
	b.conn.query("INSERT INTO history (tid, bid, aid, delta, mtime) VALUES (${tid}, ${bid}, ${aid}, ${delta}, '${now}')")!

	b.conn.query('COMMIT')!
}

// run runs transactions until the time is up. A transaction that fails with a
// serialization failure has been rolled back, so it's counted and skipped.
fn (mut w BenchmarkWorker) run() ! {
	t := vsql.start_timer()
	for t.elapsed() <= w.b.run_for {
		w.b.run_transaction() or {
			if vsql.sqlstate_from_int(err.code()) == '40001' {
				w.failed++
				continue
			}
			return err
		}
		w.committed++
	}
}

fn (b Benchmark) random(min int, max int) int {
	return (rand.int31() % (max - min + 1)) + min
}
