// speedtest1.v is a port of the "main" test set of speedtest1 from SQLite
// (test/speedtest1.c), which is in the public domain. Each test uses the same
// tables, row counts and generated values, and is numbered the same, so that
// the results can be lined up with the same test on SQLite. The differences are
// described in docs/benchmark.rst.

module main

import time
import vsql

struct Speedtest1 {
mut:
	conn &vsql.Connection
	// size is the same as --size. There are 500 * size rows in most of the tables.
	size int
	// isolation_level is used to start each transaction, unless it's empty.
	isolation_level string
	// x and y are the state of random, which starts again for each test.
	x u32
	y u32
	// The current test.
	test_number int
	test_name   string
	test_timer  vsql.Timer
	total       time.Duration
}

fn (mut s Speedtest1) start() ! {
	s.test_inserts()!
	s.test_selects()!
	s.test_create_index()!
	s.test_selects_between()!
	s.test_refill()!
	s.skip(200, 'VACUUM', 'no VACUUM')
	s.test_updates()!
	s.test_deletes()!
	s.test_joins()!
	s.test_replace()!
	s.skip(980, 'PRAGMA integrity_check', 'no integrity check')
	s.skip(990, 'ANALYZE', 'no ANALYZE')

	print_speedtest1_line('', 'TOTAL', '${s.total.seconds():.3f}s')
}

// 100-120: Insert into a table with no index, and in and out of order with a
// PRIMARY KEY.
fn (mut s Speedtest1) test_inserts() ! {
	sz := s.size * 500
	maxb := roundup_allones(u32(sz))

	s.begin_test(100, '${sz} INSERTs into table with no index')
	s.begin()!
	s.conn.query('CREATE TABLE z1 (a INTEGER, b INTEGER, c VARCHAR(200))')!
	mut stmt := s.conn.prepare('INSERT INTO z1 (a, b, c) VALUES (?, ?, ?)')!
	for i in 1 .. sz + 1 {
		x1 := swizzle(u32(i), maxb)
		s.exec(mut stmt, int(x1), i, numbername(x1))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(110, '${sz} ordered INSERTS with one index/PK')
	s.begin()!
	s.conn.query('CREATE TABLE z2 (a INTEGER, b INTEGER, c VARCHAR(200), PRIMARY KEY (a))')!
	stmt = s.conn.prepare('INSERT INTO z2 (a, b, c) VALUES (?, ?, ?)')!
	for i in 1 .. sz + 1 {
		x1 := swizzle(u32(i), maxb)
		s.exec(mut stmt, i, int(x1), numbername(x1))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(120, '${sz} unordered INSERTS with one index/PK')
	s.begin()!
	s.conn.query('CREATE TABLE t3 (a INTEGER, b INTEGER, c VARCHAR(200), PRIMARY KEY (a))')!
	stmt = s.conn.prepare('INSERT INTO t3 (a, b, c) VALUES (?, ?, ?)')!
	for i in 1 .. sz + 1 {
		x1 := swizzle(u32(i), maxb)
		s.exec(mut stmt, int(x1), i, numbername(x1))!
	}
	s.commit()!
	s.end_test()
}

// 130-145: Scans of a table with no index.
fn (mut s Speedtest1) test_selects() ! {
	sz := s.size * 500
	maxb := roundup_allones(u32(sz))

	s.begin_test(130, '25 SELECTS, numeric BETWEEN, unindexed')
	s.begin()!
	mut stmt := s.conn.prepare('SELECT COUNT(*), AVG(b), SUM(CHARACTER_LENGTH(c)) FROM z1 WHERE b BETWEEN ? AND ?')!
	for _ in 0 .. 25 {
		x1 := s.random() % maxb
		x2 := s.random() % 10 + u32(sz / 5000) + x1
		s.exec(mut stmt, int(x1), int(x2))!
	}
	s.commit()!
	s.end_test()

	for test in [
		Speedtest1Like{140, '10 SELECTS, LIKE, unindexed', 'SELECT COUNT(*), AVG(b), SUM(CHARACTER_LENGTH(c)) FROM z1 WHERE c LIKE ?'},
		Speedtest1Like{142, '10 SELECTS w/ORDER BY, unindexed', 'SELECT a, b, c FROM z1 WHERE c LIKE ? ORDER BY a'},
		Speedtest1Like{145, '10 SELECTS w/ORDER BY and LIMIT, unindexed', 'SELECT a, b, c FROM z1 WHERE c LIKE ? ORDER BY a LIMIT 10'},
	] {
		s.begin_test(test.number, test.name)
		s.begin()!
		stmt = s.conn.prepare(test.sql)!
		for i in 1 .. 11 {
			s.exec(mut stmt, '%${numbername(u32(i))}%')!
		}
		s.commit()!
		s.end_test()
	}
}

struct Speedtest1Like {
	number int
	name   string
	sql    string
}

// 150: The indexes that the rest of the tests use.
fn (mut s Speedtest1) test_create_index() ! {
	s.begin_test(150, 'CREATE INDEX five times')
	s.begin()!
	s.conn.query('CREATE UNIQUE INDEX t1b ON z1 (b)')!
	s.conn.query('CREATE INDEX t1c ON z1 (c)')!
	s.conn.query('CREATE UNIQUE INDEX t2b ON z2 (b)')!
	s.conn.query('CREATE INDEX t2c ON z2 (c DESC)')!
	s.conn.query('CREATE INDEX t3bc ON t3 (b, c)')!
	s.commit()!
	s.end_test()
}

// 160-170: Ranges of an index and a PRIMARY KEY.
fn (mut s Speedtest1) test_selects_between() ! {
	sz := s.size * 500
	n := sz / 5
	maxb := roundup_allones(u32(sz))

	s.begin_test(160, '${n} SELECTS, numeric BETWEEN, indexed')
	s.begin()!
	mut stmt := s.conn.prepare('SELECT COUNT(*), AVG(b), SUM(CHARACTER_LENGTH(c)) FROM z1 WHERE b BETWEEN ? AND ?')!
	for _ in 0 .. n {
		x1 := s.random() % maxb
		x2 := s.random() % 10 + u32(sz / 5000) + x1
		s.exec(mut stmt, int(x1), int(x2))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(161, '${n} SELECTS, numeric BETWEEN, PK')
	s.begin()!
	stmt = s.conn.prepare('SELECT COUNT(*), AVG(b), SUM(CHARACTER_LENGTH(c)) FROM z2 WHERE a BETWEEN ? AND ?')!
	for _ in 0 .. n {
		x1 := s.random() % maxb
		x2 := s.random() % 10 + u32(sz / 5000) + x1
		s.exec(mut stmt, int(x1), int(x2))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(170, '${n} SELECTS, text BETWEEN, indexed')
	s.begin()!
	stmt = s.conn.prepare('SELECT COUNT(*), AVG(b), SUM(CHARACTER_LENGTH(c)) FROM z1 WHERE c BETWEEN ? AND ?')!
	for i in 1 .. n + 1 {
		name := numbername(swizzle(u32(i), maxb))
		s.exec(mut stmt, name, '${name}~')!
	}
	s.commit()!
	s.end_test()
}

// 180-190: Fill a table from another one.
fn (mut s Speedtest1) test_refill() ! {
	sz := s.size * 500

	s.begin_test(180, '${sz} INSERTS with three indexes')
	s.begin()!
	s.conn.query('CREATE TABLE t4 (a INTEGER, b INTEGER, c VARCHAR(200), PRIMARY KEY (a))')!
	s.conn.query('CREATE INDEX t4b ON t4 (b)')!
	s.conn.query('CREATE INDEX t4c ON t4 (c)')!
	s.conn.query('INSERT INTO t4 SELECT * FROM z1')!
	s.commit()!
	s.end_test()

	s.begin_test(190, 'DELETE and REFILL one table')
	s.conn.query('DELETE FROM z2')!
	s.conn.query('INSERT INTO z2 SELECT * FROM z1')!
	s.end_test()
}

// 210-260: Add a column and change the rows.
fn (mut s Speedtest1) test_updates() ! {
	sz := s.size * 500
	n := sz / 5
	maxb := roundup_allones(u32(sz))

	s.begin_test(210, 'ALTER TABLE ADD COLUMN, and query')
	s.conn.query('ALTER TABLE z2 ADD COLUMN d INTEGER DEFAULT 123')!
	s.conn.query('SELECT SUM(d) FROM z2')!
	s.end_test()

	s.begin_test(230, '${n} UPDATES, numeric BETWEEN, indexed')
	s.begin()!
	mut stmt := s.conn.prepare('UPDATE z2 SET d = b * 2 WHERE b BETWEEN ? AND ?')!
	for _ in 0 .. n {
		x1 := s.random() % maxb
		x2 := s.random() % 10 + u32(sz / 5000) + x1
		s.exec(mut stmt, int(x1), int(x2))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(240, '${sz} UPDATES of individual rows')
	s.begin()!
	stmt = s.conn.prepare('UPDATE z2 SET d = b * 3 WHERE a = ?')!
	for _ in 0 .. sz {
		s.exec(mut stmt, int(s.random() % u32(sz) + 1))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(250, 'One big UPDATE of the whole ${sz}-row table')
	s.conn.query('UPDATE z2 SET d = b * 4')!
	s.end_test()

	s.begin_test(260, 'Query added column after filling')
	s.conn.query('SELECT SUM(d) FROM z2')!
	s.end_test()
}

// 270-300: Delete rows, then fill the tables again.
fn (mut s Speedtest1) test_deletes() ! {
	sz := s.size * 500
	n := sz / 5
	maxb := roundup_allones(u32(sz))

	s.begin_test(270, '${n} DELETEs, numeric BETWEEN, indexed')
	s.begin()!
	mut stmt := s.conn.prepare('DELETE FROM z2 WHERE b BETWEEN ? AND ?')!
	for _ in 0 .. n {
		x1 := s.random() % maxb + 1
		x2 := s.random() % 10 + u32(sz / 5000) + x1
		s.exec(mut stmt, int(x1), int(x2))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(280, '${sz} DELETEs of individual rows')
	s.begin()!
	stmt = s.conn.prepare('DELETE FROM t3 WHERE a = ?')!
	for _ in 0 .. sz {
		s.exec(mut stmt, int(s.random() % u32(sz) + 1))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(290, 'Refill two ${sz}-row tables')
	s.conn.query('DELETE FROM z2')!
	s.conn.query('INSERT INTO z2 (a, b, c) SELECT a, b, c FROM z1')!
	s.conn.query('DELETE FROM t3')!
	s.conn.query('INSERT INTO t3 (a, b, c) SELECT a, b, c FROM z1')!
	s.end_test()

	s.begin_test(300, 'Refill a ${sz}-row table using MOD(b, 2) = MOD(a, 2)')
	s.conn.query('DELETE FROM z2')!
	s.conn.query('INSERT INTO z2 (a, b, c) SELECT a, b, c FROM z1 WHERE MOD(b, 2) = MOD(a, 2)')!
	s.conn.query('INSERT INTO z2 (a, b, c) SELECT a, b, c FROM z1 WHERE MOD(b, 2) <> MOD(a, 2)')!
	s.end_test()
}

// 310 joins four tables on their PRIMARY KEYs and an index, and 320 is a subquery
// for each row. SQLite's 310 lists the tables after FROM and joins them in the
// WHERE, which vsql would run as a cross join of all four tables, so it's written
// with JOIN ... ON instead.
fn (mut s Speedtest1) test_joins() ! {
	sz := s.size * 500
	n := sz / 5

	s.begin_test(310, '${n} four-ways joins')
	s.begin()!
	mut join := s.conn.prepare('SELECT z1.c FROM t4 JOIN t3 ON t3.a = t4.b JOIN z2 ON z2.a = t3.b JOIN z1 ON z1.c = z2.c WHERE t4.a BETWEEN ? AND ?')!
	for _ in 0 .. n {
		x1 := s.random() % u32(sz) + 1
		x2 := s.random() % 10 + x1 + 4
		s.exec(mut join, int(x1), int(x2))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(320, 'subquery in result set')
	mut stmt := s.conn.prepare('SELECT a, c, (SELECT z2.a FROM z2 WHERE 5 + z2.b = z1.b) FROM z1 WHERE a < ?')!
	s.exec(mut stmt, est_square_root(s.size) * 50)!
	s.end_test()
}

// 400-520: REPLACE (an UPDATE that's followed by an INSERT if there was no row),
// and lookups on a PRIMARY KEY.
fn (mut s Speedtest1) test_replace() ! {
	sz := s.size * 700
	maxb := roundup_allones(u32(sz / 3))

	s.begin_test(400, '${sz} REPLACE ops on an integer PK')
	s.begin()!
	s.conn.query('CREATE TABLE t5 (a INTEGER, b VARCHAR(200), PRIMARY KEY (a))')!
	mut update := s.conn.prepare('UPDATE t5 SET b = ? WHERE a = ?')!
	mut insert := s.conn.prepare('INSERT INTO t5 (b, a) VALUES (?, ?)')!
	for i in 1 .. sz + 1 {
		name := numbername(u32(i))
		x1 := int(swizzle(u32(i), maxb))
		if s.exec(mut update, name, x1)!.msg == 'UPDATE 0' {
			s.exec(mut insert, name, x1)!
		}
	}
	s.commit()!
	s.end_test()

	s.begin_test(410, '${sz} SELECTS on an integer PK')
	s.begin()!
	mut stmt := s.conn.prepare('SELECT b FROM t5 WHERE a = ?')!
	for i in 1 .. sz + 1 {
		s.exec(mut stmt, int(swizzle(u32(i), maxb)))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(500, '${sz} REPLACE on TEXT PK')
	s.begin()!
	s.conn.query('CREATE TABLE t6 (a VARCHAR(200), b INTEGER, PRIMARY KEY (a))')!
	update = s.conn.prepare('UPDATE t6 SET b = ? WHERE a = ?')!
	insert = s.conn.prepare('INSERT INTO t6 (b, a) VALUES (?, ?)')!
	for i in 1 .. sz + 1 {
		name := numbername(swizzle(u32(i), maxb))
		if s.exec(mut update, i, name)!.msg == 'UPDATE 0' {
			s.exec(mut insert, i, name)!
		}
	}
	s.commit()!
	s.end_test()

	s.begin_test(510, '${sz} SELECTS on a TEXT PK')
	s.begin()!
	stmt = s.conn.prepare('SELECT b FROM t6 WHERE a = ?')!
	for i in 1 .. sz + 1 {
		s.exec(mut stmt, numbername(swizzle(u32(i), maxb)))!
	}
	s.commit()!
	s.end_test()

	s.begin_test(520, '${sz} SELECT DISTINCT')
	s.conn.query('SELECT DISTINCT b FROM t5')!
	s.conn.query('SELECT DISTINCT b FROM t6')!
	s.end_test()
}

type Speedtest1Param = int | string

// exec runs a statement with values for its "?"s.
fn (mut s Speedtest1) exec(mut stmt vsql.PreparedStmt, params ...Speedtest1Param) !vsql.Result {
	mut values := map[string]vsql.Value{}
	for i, param in params {
		values['?${i + 1}'] = match param {
			int { vsql.new_integer_value(param) }
			string { vsql.new_varchar_value(param) }
		}
	}

	return stmt.query(values)
}

fn (mut s Speedtest1) begin() ! {
	if s.isolation_level == '' {
		s.conn.query('START TRANSACTION')!
	} else {
		s.conn.query('START TRANSACTION ISOLATION LEVEL ${s.isolation_level}')!
	}
}

fn (mut s Speedtest1) commit() ! {
	s.conn.query('COMMIT')!
}

fn (mut s Speedtest1) begin_test(number int, name string) {
	s.test_number = number
	s.test_name = name
	s.x = 0xad131d0b
	s.y = 0x44f9eac8
	s.test_timer = vsql.start_timer()
}

fn (mut s Speedtest1) end_test() {
	elapsed := s.test_timer.elapsed()
	s.total += elapsed
	print_speedtest1_line('${s.test_number} - ', s.test_name, '${elapsed.seconds():.3f}s')
}

fn (mut s Speedtest1) skip(number int, name string, reason string) {
	print_speedtest1_line('${number} - ', name, 'skipped (${reason})')
}

fn print_speedtest1_line(prefix string, name string, result string) {
	dots := '.'.repeat(if name.len < 60 { 60 - name.len } else { 0 })
	println('${prefix}${name}${dots} ${result}')
}

// random is speedtest1_random, which returns the same numbers as SQLite.
fn (mut s Speedtest1) random() u32 {
	s.x = (s.x >> 1) ^ ((1 + ~(s.x & 1)) & 0xd0000001)
	s.y = s.y * 1103515245 + 12345
	return s.x ^ s.y
}

// swizzle reverses the low bits of n, for as many bits as there are in limit, so
// that 1 to limit come out of order, but only once each.
fn swizzle(n u32, limit u32) u32 {
	mut input := n
	mut remaining := limit
	mut out := u32(0)
	for remaining > 0 {
		out = (out << 1) | (input & 1)
		input >>= 1
		remaining >>= 1
	}
	return out
}

// roundup_allones returns the smallest number that's at least limit, and is one
// less than a power of two.
fn roundup_allones(limit u32) u32 {
	mut m := u32(1)
	for m < limit {
		m = (m << 1) + 1
	}
	return m
}

// numbername returns the English name of n, such as "one hundred twenty three".
fn numbername(n u32) string {
	ones := ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
		'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen',
		'nineteen']
	tens := ['', 'ten', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety']

	mut parts := []string{}
	mut rest := n
	if rest >= 1000000000 {
		parts << '${numbername(rest / 1000000000)} billion'
		rest %= 1000000000
	}
	if rest >= 1000000 {
		parts << '${numbername(rest / 1000000)} million'
		rest %= 1000000
	}
	if rest >= 1000 {
		parts << '${numbername(rest / 1000)} thousand'
		rest %= 1000
	}
	if rest >= 100 {
		parts << '${ones[rest / 100]} hundred'
		rest %= 100
	}
	if rest >= 20 {
		parts << tens[rest / 10]
		rest %= 10
	}
	if rest > 0 {
		parts << ones[rest]
	}
	if parts.len == 0 {
		return 'zero'
	}

	return parts.join(' ')
}

// est_square_root returns about the square root of x.
fn est_square_root(x int) int {
	mut y0 := x / 2
	for _ in 0 .. 10 {
		if y0 <= 0 {
			break
		}
		y1 := (y0 + x / y0) / 2
		if y1 == y0 {
			break
		}
		y0 = y1
	}
	return y0
}
