// benchmark.v contains functionality to benchmark the performance of vsql. This is
// useful as a local tool and provides insights into changes for performance
// between vsql versions. The test itself is inspired/copied from pgbench.
//
// Usage:
//
//   vsql bench
//
// The tpc-b suite is the tpc-b-setup suite (which creates the tables and inserts
// the rows), the tpc-b-oltp suite (which runs the transactions) and then the
// tpc-b-check suite (which checks the rows and totals).
//
// See https://github.com/elliotchance/vsql/blob/main/docs/benchmark.rst

module main

import rand
import runtime
import time
import vsql

struct Benchmark {
mut:
	conn         &vsql.Connection
	account_rows int
	teller_rows  int
	branch_rows  int
	run_for      time.Duration
	// peak_memory is the most memory (resident set size) the process has used,
	// in bytes. It's sampled while the benchmark runs (see sample_memory), so
	// it's 0 if the platform can't report it.
	peak_memory u64
	// isolation_level is used to start each transaction, such as
	// "READ COMMITTED", unless it's empty.
	isolation_level string
}

// new_benchmark creates a benchmark of a size (at least 1), which multiplies the
// number of rows in each table, like the scale factor of pgbench.
fn new_benchmark(conn &vsql.Connection, size int) Benchmark {
	return Benchmark{
		account_rows: 100000 * size
		teller_rows:  10 * size
		branch_rows:  size
		run_for:      time.minute
		conn:         conn
	}
}

// setup is the tpc-b-setup suite. It creates the TPC_B schema and its tables,
// and inserts the rows.
fn (mut b Benchmark) setup() ! {
	// The tables are in their own schema, so that the benchmark can run on an
	// existing database without touching its other tables. CREATE SCHEMA fails
	// if the schema already exists, rather than using its tables.
	b.conn.query('CREATE SCHEMA tpc_b') or {
		return error('${err.msg()} (use DROP SCHEMA tpc_b CASCADE to remove it and its tables)')
	}
	b.conn.query('CREATE TABLE tpc_b.accounts ( aid INT, abalance INT, PRIMARY KEY ( aid ) ) ')!

	mut t := vsql.start_timer()
	for aid in 1 .. b.account_rows + 1 {
		b.conn.query('INSERT INTO tpc_b.accounts (aid, abalance) VALUES (${aid}, 0)')!
		if aid % 100 == 0 {
			b.sample_memory()
		}
	}
	b.sample_memory()
	println('')
	println('# tpc-b-setup')
	print_rate('insert', b.account_rows, 'rows', t.elapsed())

	b.conn.query('CREATE TABLE tpc_b.tellers ( tid INT, tbalance INT, PRIMARY KEY ( tid ) ) ')!
	for tid in 1 .. b.teller_rows + 1 {
		b.conn.query('INSERT INTO tpc_b.tellers (tid, tbalance) VALUES (${tid}, 0)')!
	}

	b.conn.query('CREATE TABLE tpc_b.branches ( bid INT, bbalance INT, PRIMARY KEY ( bid ) ) ')!
	for bid in 1 .. b.branch_rows + 1 {
		b.conn.query('INSERT INTO tpc_b.branches (bid, bbalance) VALUES (${bid}, 0)')!
	}

	b.conn.query('CREATE TABLE tpc_b.history ( tid INT, bid INT, aid INT, delta INT, mtime TIMESTAMP ) ')!
}

// read_size sets the number of rows of each table from a database that the
// tpc-b-setup suite created, so that tpc-b-oltp uses the same size.
fn (mut b Benchmark) read_size() ! {
	mut result := b.conn.query('SELECT COUNT(*) FROM tpc_b.branches')!
	row := result.next() or { return error('TPC_B.BRANCHES has no rows') }
	size := row.get_int('COL1')!
	if size < 1 {
		return error('TPC_B.BRANCHES has no rows, run -suite tpc-b-setup first')
	}
	b.account_rows = 100000 * size
	b.teller_rows = 10 * size
	b.branch_rows = size
}

// oltp is the tpc-b-oltp suite. It reads every row of ACCOUNTS, then runs as
// many transactions as it can in run_for. A transaction that fails with a 40001
// serialization failure (because of another connection) has been rolled back,
// so it's counted and the next one is run, like a client would retry it.
fn (mut b Benchmark) oltp() ! {
	mut t := vsql.start_timer()

	b.conn.query('SELECT abalance FROM tpc_b.accounts WHERE abalance = 0')!
	b.sample_memory()
	println('')
	println('# tpc-b-oltp')
	print_rate('select', b.account_rows, 'rows', t.elapsed())

	t = vsql.start_timer()
	mut txn_count := 0
	mut failures := 0
	for {
		mut committed := true
		b.run_transaction() or {
			if vsql.sqlstate_from_int(err.code()) != '40001' {
				return err
			}
			b.conn.query('ROLLBACK') or {}
			committed = false
		}
		if committed {
			txn_count++
			if txn_count % 10 == 0 {
				b.sample_memory()
			}
		} else {
			failures++
		}

		if t.elapsed() > b.run_for {
			break
		}
	}

	print_value('transactions', txn_count.str())
	print_value('transactions_seconds', '${t.elapsed().seconds():.3f}')
	print_value('transactions_per_second', '${txn_count / t.elapsed().seconds():.3f}')
	print_value('serialization_failures', failures.str())
}

// check is the tpc-b-check suite. It checks that each table has the number of
// rows that tpc-b-setup inserted, and that the balances of ACCOUNTS, TELLERS
// and BRANCHES each add up to the total of the deltas in HISTORY. Every
// transaction adds its delta to one row of each, so the totals are only
// different if a transaction was partly lost or applied more than once.
fn (mut b Benchmark) check() ! {
	mut t := vsql.start_timer()

	for table, want in {
		'accounts': b.account_rows
		'tellers':  b.teller_rows
		'branches': b.branch_rows
	} {
		got := b.query_value('SELECT COUNT(*) FROM tpc_b.${table}')!
		if got != want.str() {
			return error('check failed: TPC_B.${table.to_upper()} has ${got} rows, expected ${want}')
		}
	}

	history_rows := b.query_value('SELECT COUNT(*) FROM tpc_b.history')!
	total := b.query_value('SELECT COALESCE(SUM(delta), 0) FROM tpc_b.history')!
	for table, column in {
		'accounts': 'abalance'
		'tellers':  'tbalance'
		'branches': 'bbalance'
	} {
		got := b.query_value('SELECT COALESCE(SUM(${column}), 0) FROM tpc_b.${table}')!
		if got != total {
			return error('check failed: the total of TPC_B.${table.to_upper()} is ${got}, expected ${total} (the total of TPC_B.HISTORY)')
		}
	}

	b.sample_memory()
	println('')
	println('# tpc-b-check')
	print_value('check_history_rows', history_rows)
	print_value('check_total', total)
	print_value('check_seconds', '${t.elapsed().seconds():.3f}')
}

// query_value returns the first column of the first row of a query, as a
// string.
fn (mut b Benchmark) query_value(query string) !string {
	mut result := b.conn.query(query)!
	row := result.next() or { return error('no rows from: ${query}') }
	return row.get_string('COL1')!
}

// print_peak_memory prints the most memory the process used, see sample_memory.
fn (mut b Benchmark) print_peak_memory() {
	b.sample_memory()
	if b.peak_memory > 0 {
		println('')
		print_value('peak_memory_mib', '${f64(b.peak_memory) / (1024 * 1024):.1f}')
	}
}

// sample_memory updates peak_memory with the memory the process is using now.
fn (mut b Benchmark) sample_memory() {
	used := runtime.used_memory() or { return }
	if used > b.peak_memory {
		b.peak_memory = used
	}
}

// print_rate prints the number of things (such as rows), how long they took and
// how many that is per second, as name_unit, name_seconds and
// name_unit_per_second.
fn print_rate(name string, n int, unit string, elapsed time.Duration) {
	print_value('${name}_${unit}', n.str())
	print_value('${name}_seconds', '${elapsed.seconds():.3f}')
	print_value('${name}_${unit}_per_second', '${n / elapsed.seconds():.3f}')
}

// print_value prints a "name=value" line. The value is quoted (for a shell)
// unless it only has characters that a shell doesn't treat specially.
fn print_value(name string, value string) {
	if value.len > 0 && value.bytes().all(it.is_alnum() || it in '_-+.,:/@%'.bytes()) {
		println('${name}=${value}')
	} else {
		println("${name}='${value.replace("'", "'\\''")}'")
	}
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

	b.conn.query('UPDATE tpc_b.accounts SET abalance = abalance + ${delta} WHERE aid = ${aid}')!
	b.conn.query('SELECT abalance FROM tpc_b.accounts WHERE aid = ${aid}')!
	b.conn.query('UPDATE tpc_b.tellers SET tbalance = tbalance + ${delta} WHERE tid = ${tid}')!
	b.conn.query('UPDATE tpc_b.branches SET bbalance = bbalance + ${delta} WHERE bid = ${bid}')!

	b.conn.query('INSERT INTO tpc_b.history (tid, bid, aid, delta, mtime) VALUES (${tid}, ${bid}, ${aid}, ${delta}, CURRENT_TIMESTAMP)')!

	b.conn.query('COMMIT')!
}

// random returns a number from min to max (including both).
fn (b Benchmark) random(min int, max int) int {
	return (rand.int31() % (max - min + 1)) + min
}
