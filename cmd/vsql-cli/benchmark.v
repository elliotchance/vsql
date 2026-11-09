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

import os
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
}

fn new_benchmark(conn &vsql.Connection) Benchmark {
	return Benchmark{
		account_rows: 100000
		teller_rows:  10
		branch_rows:  1
		run_for:      time.minute
		conn:         conn
	}
}

// set_options changes the number of accounts and the seconds to run
// transactions for, when they aren't 0.
fn (mut b Benchmark) set_options(accounts int, duration int) {
	if accounts > 0 {
		b.account_rows = accounts
	}
	if duration > 0 {
		b.run_for = duration * time.second
	}
}

fn (mut b Benchmark) start() ! {
	b.setup()!

	t := vsql.start_timer()
	mut txn_count := 0
	for {
		b.run_transaction()!
		txn_count++
		if txn_count % 10 == 0 {
			b.sample_memory()
		}

		if t.elapsed() > b.run_for {
			break
		}
	}

	b.print_stat('TPC-B (sort of)', txn_count, 'transactions', t.elapsed())

	b.sample_memory()
	if b.peak_memory > 0 {
		println('Peak memory: ${f64(b.peak_memory) / (1024 * 1024):.1f} MiB')
	}
}

// setup creates the tables and their rows.
fn (mut b Benchmark) setup() ! {
	b.conn.query('CREATE TABLE accounts ( aid INT, abalance INT, PRIMARY KEY ( aid ) ) ')!

	mut t := vsql.start_timer()
	for aid in 1 .. b.account_rows + 1 {
		b.conn.query('INSERT INTO accounts (aid, abalance) VALUES (${aid}, 0)')!
		if aid % 100 == 0 {
			b.sample_memory()
		}
	}
	b.sample_memory()
	b.print_stat('INSERT', b.account_rows, 'rows', t.elapsed())

	b.conn.query('CREATE TABLE tellers ( tid INT, tbalance INT, PRIMARY KEY ( tid ) ) ')!
	for tid in 1 .. b.teller_rows + 1 {
		b.conn.query('INSERT INTO tellers (tid, tbalance) VALUES (${tid}, 0)')!
	}

	b.conn.query('CREATE TABLE branches ( bid INT, bbalance INT, PRIMARY KEY ( bid ) ) ')!
	for bid in 1 .. b.branch_rows + 1 {
		b.conn.query('INSERT INTO branches (bid, bbalance) VALUES (${bid}, 0)')!
	}

	b.conn.query('CREATE TABLE history ( tid INT, bid INT, aid INT, delta INT, mtime TIMESTAMP ) ')!

	t = vsql.start_timer()

	b.conn.query('SELECT abalance FROM accounts WHERE abalance = 0')!
	b.sample_memory()
	b.print_stat('SELECT', b.account_rows, 'rows', t.elapsed())
}

// run_processes starts processes that each run transactions on file at the same
// time (see run_worker). When they've all finished, every balance must be the
// sum of the deltas in history for it, and history must have a row for each
// transaction that was committed.
fn (mut b Benchmark) run_processes(file string, processes int) ! {
	b.setup()!

	// The connection isn't used while the processes run, so they only share
	// the file.
	args := [os.executable(), 'bench', '-worker', '-file', file, '-accounts', '${b.account_rows}',
		'-duration', '${int(b.run_for.seconds())}']
	t := vsql.start_timer()
	mut threads := []thread os.Result{}
	for _ in 0 .. processes {
		threads << spawn os.exec(args)
	}
	results := threads.wait()
	elapsed := t.elapsed()

	mut committed := 0
	mut rolled_back := 0
	for i, result in results {
		if result.exit_code != 0 {
			return error('process ${i + 1} failed (exit code ${result.exit_code}): ${result.output.trim_space()}')
		}
		parts := result.output.trim_space().split(' ')
		if parts.len != 2 {
			return error('process ${i + 1} printed: ${result.output.trim_space()}')
		}
		println('Process ${i + 1}: ${parts[0]} committed, ${parts[1]} rolled back')
		if parts[0].int() == 0 {
			return error("process ${i + 1} didn't commit any transactions")
		}
		committed += parts[0].int()
		rolled_back += parts[1].int()
	}

	b.print_stat('TPC-B (sort of)', committed, 'transactions', elapsed)
	println('Rolled back: ${rolled_back} transactions')

	b.check_balances('accounts', 'aid', 'abalance')!
	b.check_balances('tellers', 'tid', 'tbalance')!
	b.check_balances('branches', 'bid', 'bbalance')!
	history := b.conn.query('SELECT COUNT(*) AS c FROM history')!
	for row in history {
		count := row.get_int('C')!
		if count != committed {
			return error('history has ${count} rows, but ${committed} transactions were committed')
		}
	}
	println('Balances: OK')
}

// check_balances returns an error if a balance of table isn't the sum of the
// deltas for its row in history.
fn (mut b Benchmark) check_balances(table string, id string, balance string) ! {
	rows := b.conn.query('SELECT t.${id} AS id, t.${balance} AS balance, COALESCE(h.total, 0) AS total FROM ${table} AS t LEFT JOIN (SELECT ${id}, SUM(delta) AS total FROM history GROUP BY ${id}) AS h ON t.${id} = h.${id} WHERE t.${balance} <> COALESCE(h.total, 0)')!
	for row in rows {
		return error('${table} ${row.get_string('ID')!} has a balance of ${row.get_string('BALANCE')!}, but its deltas add up to ${row.get_string('TOTAL')!}')
	}
}

// run_worker runs transactions until run_for has passed, then prints how many
// were committed and how many were rolled back, because another process changed
// a row first.
fn (mut b Benchmark) run_worker() ! {
	t := vsql.start_timer()
	mut committed := 0
	mut rolled_back := 0
	for t.elapsed() <= b.run_for {
		b.run_transaction() or {
			if vsql.sqlstate_from_int(err.code()).starts_with('40') {
				b.conn.query('ROLLBACK') or {}
				rolled_back++
				continue
			}
			return err
		}
		committed++
	}
	println('${committed} ${rolled_back}')
}

// sample_memory updates peak_memory with the memory the process is using now.
fn (mut b Benchmark) sample_memory() {
	used := runtime.used_memory() or { return }
	if used > b.peak_memory {
		b.peak_memory = used
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

	b.conn.query('START TRANSACTION')!

	b.conn.query('UPDATE accounts SET abalance = abalance + ${delta} WHERE aid = ${aid}')!
	b.conn.query('SELECT abalance FROM accounts WHERE aid = ${aid}')!
	b.conn.query('UPDATE tellers SET tbalance = tbalance + ${delta} WHERE tid = ${tid}')!
	b.conn.query('UPDATE branches SET bbalance = bbalance + ${delta} WHERE bid = ${bid}')!

	b.conn.query('INSERT INTO history (tid, bid, aid, delta, mtime) VALUES (${tid}, ${bid}, ${aid}, ${delta}, CURRENT_TIMESTAMP)')!

	b.conn.query('COMMIT')!
}

fn (b Benchmark) random(min int, max int) int {
	if min == max {
		return min
	}

	return (rand.int31() % (max - min)) + min
}
