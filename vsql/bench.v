// bench.v contains functionality to benchmark the performance of vsql. This is
// useful as a local tool and provides insights into changes for performance
// between vsql versions. The test itself is inspired/copied from pgbench.
//
// Usage:
//
//   vsql bench
//
// See https://github.com/elliotchance/vsql/blob/main/docs/benchmark.rst

module vsql

import rand
import time

pub struct Benchmark {
pub mut:
	conn         Connection
	account_rows int
	teller_rows  int
	branch_rows  int
	run_for      time.Duration
}

pub fn new_benchmark(conn Connection) Benchmark {
	return Benchmark{
		account_rows: 100000
		teller_rows: 10
		branch_rows: 1
		run_for: time.minute
		conn: conn
	}
}

pub fn (mut b Benchmark) start() ? {
	b.conn.query('CREATE TABLE accounts ( aid INT, abalance INT ) ') ?

	mut t := start_timer()
	for aid in 1 .. b.account_rows + 1 {
		b.conn.query('INSERT INTO accounts (aid, abalance) VALUES ($aid, 0)') ?
	}
	b.print_stat('INSERT', b.account_rows, 'rows', t.elapsed())

	b.conn.query('CREATE TABLE tellers ( tid INT, tbalance INT ) ') ?
	for tid in 1 .. b.teller_rows + 1 {
		b.conn.query('INSERT INTO tellers (tid, tbalance) VALUES ($tid, 0)') ?
	}

	b.conn.query('CREATE TABLE branches ( bid INT, bbalance INT ) ') ?
	for bid in 1 .. b.branch_rows + 1 {
		b.conn.query('INSERT INTO branches (bid, bbalance) VALUES ($bid, 0)') ?
	}

	b.conn.query('CREATE TABLE history ( tid INT, bid INT, aid INT, delta INT, mtime VARCHAR(30) ) ') ?

	t = start_timer()
	b.conn.query('SELECT abalance FROM accounts WHERE aid = 0') ?
	b.print_stat('SELECT', b.account_rows, 'rows', t.elapsed())

	t = start_timer()
	mut txn_count := 0
	for {
		b.run_transaction() ?
		txn_count++

		if t.elapsed() > b.run_for {
			break
		}
	}

	b.print_stat('TCP-B (sort of)', txn_count, 'transactions', t.elapsed())
}

fn (mut b Benchmark) print_stat(name string, n int, unit string, elapsed time.Duration) {
	println('$name: $n $unit in ${elapsed.seconds():.3f} (${n / elapsed.seconds():.3f} $unit/s)')
}

fn (mut b Benchmark) run_transaction() ? {
	aid := b.random(1, b.account_rows)
	bid := b.random(1, b.branch_rows)
	tid := b.random(1, b.teller_rows)
	delta := b.random(-5000, 5000)

	b.conn.query('UPDATE accounts SET abalance = abalance + $delta WHERE aid = $aid') ?
	b.conn.query('SELECT abalance FROM accounts WHERE aid = $aid') ?
	b.conn.query('UPDATE tellers SET tbalance = tbalance + $delta WHERE tid = $tid') ?
	b.conn.query('UPDATE branches SET bbalance = bbalance + $delta WHERE bid = $bid') ?

	// TODO(elliotchance): Should use CURRENT_TIMESTAMP once supported.
	b.conn.query('INSERT INTO history (tid, bid, aid, delta, mtime) VALUES ($tid, $bid, $aid, $delta, \'$time.now()\')') ?
}

fn (b Benchmark) random(min int, max int) int {
	if min == max {
		return min
	}

	return (rand.int31() % (max - min)) + min
}
