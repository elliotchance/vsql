module vsql

// isolation_test.v tests the isolation levels and the isolation lock.

import os
import time

fn test_transaction_isolation_level() ! {
	mut db := open(':memory:')!
	for level in ['READ UNCOMMITTED', 'READ COMMITTED', 'REPEATABLE READ', 'SERIALIZABLE'] {
		db.query('START TRANSACTION ISOLATION LEVEL ${level}')!
		assert db.transaction_isolation_level() == level
		db.query('COMMIT')!
	}
	db.query('START TRANSACTION')!
	assert db.transaction_isolation_level() == 'SERIALIZABLE'
	db.query('COMMIT')!
}

fn test_default_isolation_level() ! {
	mut options := default_connection_options()
	options.isolation_level = .read_committed
	mut db := open_database(':memory:', options)!
	assert db.transaction_isolation_level() == 'READ COMMITTED'
	db.query('START TRANSACTION')!
	assert db.transaction_isolation_level() == 'READ COMMITTED'
	db.query('COMMIT')!
	db.query('START TRANSACTION ISOLATION LEVEL SERIALIZABLE')!
	assert db.transaction_isolation_level() == 'SERIALIZABLE'
	db.query('COMMIT')!
	// A statement on its own, and the next SQL-transaction, are back to it.
	db.query('CREATE TABLE t (x INT)')!
	assert db.transaction_isolation_level() == 'READ COMMITTED'
	db.query('SET TRANSACTION DIAGNOSTICS SIZE 1')!
	assert db.next_transaction_characteristics() == 'ISOLATION LEVEL READ COMMITTED, DIAGNOSTICS SIZE 1'
}

fn test_next_transaction_characteristics() ! {
	mut db := open(':memory:')!
	assert db.next_transaction_characteristics() == ''
	assert db.next_diagnostics_size() == 0
	db.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED')!
	assert db.next_transaction_characteristics() == 'ISOLATION LEVEL READ COMMITTED'
	assert db.next_diagnostics_size() == 0
	db.query('SET TRANSACTION DIAGNOSTICS SIZE 1')!
	assert db.next_transaction_characteristics() == 'ISOLATION LEVEL SERIALIZABLE, DIAGNOSTICS SIZE 1'
	assert db.next_diagnostics_size() == 1
	db.query('SET TRANSACTION READ ONLY')!
	assert db.next_transaction_characteristics() == 'ISOLATION LEVEL SERIALIZABLE, READ ONLY'
	db.query('SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED')!
	assert db.next_transaction_characteristics() == 'ISOLATION LEVEL READ UNCOMMITTED'

	// They're used up by the next SQL-transaction.
	db.query('START TRANSACTION')!
	assert db.next_transaction_characteristics() == ''
	db.query('COMMIT')!
}

// A direct SQL statement that starts a transaction uses the isolation level of
// a SET TRANSACTION, and of the transaction that a query started.
fn test_direct_isolation_level() ! {
	mut db := open(':memory:')!
	db.direct('CREATE TABLE t (x INT);')!
	assert db.transaction_isolation_level() == 'SERIALIZABLE'
	db.direct('COMMIT;')!
	db.direct('SET TRANSACTION ISOLATION LEVEL READ COMMITTED;')!
	db.direct('INSERT INTO t (x) VALUES (1);')!
	assert db.transaction_isolation_level() == 'READ COMMITTED'
	db.direct('COMMIT;')!
	db.direct('SET TRANSACTION ISOLATION LEVEL READ COMMITTED;')!
	db.direct('SELECT * FROM t;')!
	db.direct('INSERT INTO t (x) VALUES (2);')!
	assert db.in_transaction() && db.transaction_isolation_level() == 'READ COMMITTED'
	db.direct('COMMIT;')!
}

// A query that starts an SQL-transaction in direct doesn't lock anything, so
// another connection can commit. The next statement then fails, rather than
// seeing it.
fn test_direct_query_isolation() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-direct-query-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'test.vsql')
	options := isolation_test_options(0)
	conflict := '40001 serialization failure: another connection has committed since this transaction started reading'

	mut a := open_database(path, options)!
	defer {
		a.close()
	}
	mut b := open_database(path, options)!
	defer {
		b.close()
	}
	b.query('CREATE TABLE t (x INT)')!
	b.query('INSERT INTO t (x) VALUES (1)')!

	// A commit that started after the first query. The transaction is over, so
	// the next query sees it, and it can be committed.
	assert a.direct('SELECT * FROM t;')!.rows.len == 1
	assert a.direct('SELECT * FROM t;')!.rows.len == 1
	b.query('INSERT INTO t (x) VALUES (2)')!
	assert direct_error(mut a, 'SELECT * FROM t;') == conflict
	assert !a.is_active()
	assert a.direct('SELECT * FROM t;')!.rows.len == 2
	assert a.direct('COMMIT;')!.msg == 'COMMIT'

	// A transaction that's still active doesn't matter until it commits, whether
	// it started after the first query or before it.
	a.direct('SELECT * FROM t;')!
	b.query('START TRANSACTION')!
	b.query('INSERT INTO t (x) VALUES (3)')!
	assert a.direct('SELECT * FROM t;')!.rows.len == 2
	b.query('COMMIT')!
	assert direct_error(mut a, 'SELECT * FROM t;') == conflict
	b.query('START TRANSACTION')!
	b.query('INSERT INTO t (x) VALUES (4)')!
	assert a.direct('SELECT * FROM t;')!.rows.len == 3
	assert a.direct('SELECT * FROM t;')!.rows.len == 3
	b.query('COMMIT')!
	assert direct_error(mut a, 'SELECT * FROM t;') == conflict

	// A rollback looks the same in the file.
	a.direct('SELECT * FROM t;')!
	b.query('START TRANSACTION')!
	b.query('ROLLBACK')!
	assert direct_error(mut a, 'SELECT * FROM t;') == conflict

	// The same goes for the statement that starts the transaction in storage,
	// which is rolled back, and the lock is released.
	a.direct('SELECT * FROM t;')!
	b.query('INSERT INTO t (x) VALUES (5)')!
	assert direct_error(mut a, 'INSERT INTO t (x) VALUES (6);') == conflict
	assert !a.is_active()
	assert b.query('SELECT * FROM t')!.rows.len == 5
	b.query('INSERT INTO t (x) VALUES (6)')!

	// With nothing in the way, it becomes a normal transaction, which also
	// holds the lock.
	a.direct('SELECT * FROM t;')!
	a.direct('INSERT INTO t (x) VALUES (7);')!
	assert a.in_transaction()
	assert query_error(mut b, 'INSERT INTO t (x) VALUES (8)') == '40001 serialization failure: another connection has a transaction that must finish first'
	assert a.direct('SELECT * FROM t;')!.rows.len == 7
	a.direct('COMMIT;')!

	// Queries don't conflict with each other, and don't create the isolation
	// file, which may not be possible.
	mut c := open_database(path, options)!
	defer {
		c.close()
	}
	os.rm(isolation_path(path))!
	a.direct('SELECT * FROM t;')!
	c.direct('SELECT * FROM t;')!
	a.direct('SELECT * FROM t;')!
	c.direct('SELECT * FROM t;')!
	assert !os.exists(isolation_path(path))
	a.direct('COMMIT;')!
	c.direct('COMMIT;')!

	// READ COMMITTED is meant to see it.
	a.direct('SET TRANSACTION ISOLATION LEVEL READ COMMITTED;')!
	a.direct('SELECT * FROM t;')!
	b.query('INSERT INTO t (x) VALUES (9)')!
	assert a.direct('SELECT * FROM t;')!.rows.len == 8
	a.direct('COMMIT;')!

	// REPEATABLE READ runs as SERIALIZABLE.
	a.direct('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;')!
	a.direct('SELECT * FROM t;')!
	b.query('INSERT INTO t (x) VALUES (10)')!
	assert direct_error(mut a, 'SELECT * FROM t;') == conflict
}

fn direct_error(mut conn Connection, sql_stmt string) string {
	conn.direct(sql_stmt) or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

fn test_isolation_lock() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-isolation-lock-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	path := isolation_path(os.join_path(dir, 'test.vsql'))

	mut a := IsolationLock{
		path: path
	}
	mut b := IsolationLock{
		path: path
	}

	// An exclusive lock conflicts with every other lock.
	a.acquire(.exclusive, 0, 'busy')!
	assert os.exists(path)
	assert isolation_lock_error(mut b, .shared, 0) == '40001 serialization failure: busy'
	assert b.state == .unlocked
	assert isolation_lock_error(mut b, .exclusive, 0) == '40001 serialization failure: busy'
	a.release()

	// The file stays open, so it doesn't have to be opened again.
	assert a.file.is_opened && a.state == .unlocked
	b.acquire(.exclusive, 0, 'busy')!
	b.release()

	// Shared locks don't conflict with each other, and a lock that is already
	// held is kept as it is.
	a.acquire(.shared, 0, 'busy')!
	b.acquire(.shared, 0, 'busy')!
	a.acquire(.exclusive, 0, 'busy')!
	assert a.state == .shared
	b.release()
	b.release()
	a.release()

	// It waits for up to the timeout.
	a.acquire(.exclusive, 0, 'busy')!
	t := time.now()
	assert isolation_lock_error(mut b, .exclusive, 20 * time.millisecond) == '40001 serialization failure: busy'
	assert time.since(t) >= 20 * time.millisecond

	// Another thread releases it while it's waiting.
	waiter := spawn fn [path] () !time.Duration {
		mut l := IsolationLock{
			path: path
		}
		t := time.now()
		l.acquire(.exclusive, 5 * time.second, 'busy')!
		l.close()
		return time.since(t)
	}()
	time.sleep(50 * time.millisecond)
	a.release()
	assert waiter.wait()! >= 40 * time.millisecond

	// A connection that releases the lock and needs it again has to wait for
	// the connection that was already waiting.
	a.acquire(.exclusive, 0, 'busy')!
	next := spawn fn [path] () !time.Time {
		mut l := IsolationLock{
			path: path
		}
		l.acquire(.exclusive, 5 * time.second, 'busy')!
		got := time.now()
		time.sleep(20 * time.millisecond)
		l.close()
		return got
	}()
	time.sleep(50 * time.millisecond)
	a.release()
	a.acquire(.exclusive, 5 * time.second, 'busy')!
	again := time.now()
	a.release()
	assert next.wait()! < again

	// The timeout includes the time spent waiting for a turn, which isn't
	// needed without a timeout.
	mut turn := IsolationLock{
		path: isolation_queue_path(path)
	}
	turn.acquire(.exclusive, 0, 'busy')!
	assert isolation_lock_error(mut a, .exclusive, 20 * time.millisecond) == '40001 serialization failure: busy'
	a.acquire(.exclusive, 0, 'busy')!
	turn.release()

	// Closing it releases the lock and closes both files.
	a.close()
	assert !a.file.is_opened && !a.queue.file.is_opened && a.state == .unlocked
	b.acquire(.exclusive, 0, 'busy')!
	b.close()
	assert !b.file.is_opened && !b.queue.file.is_opened
	turn.close()

	// A database in memory is never locked, and has no queue.
	mut m := IsolationLock{}
	m.acquire(.exclusive, 0, 'busy')!
	assert m.state == .unlocked
	m.close()
	assert isnil(m.queue)
}

// The isolation files of a connection are kept open between statements, and
// are closed with the connection.
fn test_isolation_files_closed_with_connection() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-isolation-files-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'test.vsql')

	mut db := open(path)!
	db.query('CREATE TABLE t (x INT)')!
	db.query('INSERT INTO t (x) VALUES (1)')!
	mut catalog := db.catalogs[catalog_name_from_path(path)] or { panic('no catalog') }
	assert catalog.storage.isolation.file.is_opened
	assert catalog.storage.isolation.state == .unlocked
	assert catalog.storage.isolation.queue.file.is_opened
	db.close()
	assert !catalog.storage.isolation.file.is_opened
	assert !catalog.storage.isolation.queue.file.is_opened
}

fn isolation_lock_error(mut l IsolationLock, state IsolationLockState, timeout time.Duration) string {
	l.acquire(state, timeout, 'busy') or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

// Connections that keep coming back for the isolation lock take turns with the
// ones that are already waiting for it (#559). Without that, the connection
// that released the lock would take it straight back, and keep it until all of
// its work was done.
fn test_isolation_lock_turns() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-isolation-turns-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	path := isolation_path(os.join_path(dir, 'test.vsql'))

	mut a := IsolationLock{
		path: path
	}
	a.acquire(.exclusive, 0, 'busy')!
	shared turns := []int{}
	mut threads := []thread !{}
	for id in 0 .. 3 {
		threads << spawn isolation_lock_take_turns(path, id, shared turns)
	}
	time.sleep(50 * time.millisecond)
	a.release()
	threads.wait()

	// Each one takes 15 turns. They can't take two in a row while another one is
	// waiting, but one may get a second turn when the machine is slow, so only
	// three in a row is a failure. Once one of them has finished, the others
	// aren't always waiting.
	rlock turns {
		assert turns.len == 45
		mut taken := [0, 0, 0]
		mut run := 0
		for i, id in turns {
			if 15 in taken {
				break
			}
			taken[id]++
			run = if i > 0 && id == turns[i - 1] { run + 1 } else { 1 }
			assert run <= 2, 'turns: ${turns}'
		}
	}
}

fn isolation_lock_take_turns(path string, id int, shared turns []int) ! {
	mut l := IsolationLock{
		path: path
	}
	for _ in 0 .. 15 {
		l.acquire(.exclusive, 5 * time.second, 'busy')!
		lock turns {
			turns << id
		}
		time.sleep(10 * time.millisecond)
		l.release()
	}
}

fn isolation_test_options(lock_timeout time.Duration) ConnectionOptions {
	mut options := default_connection_options()
	options.lock_timeout = lock_timeout
	return options
}

// A transaction includes every catalog, so a REPEATABLE READ or SERIALIZABLE
// transaction locks every database file, and committing changes needs every
// file that was changed to be unlocked.
fn test_isolation_with_catalogs() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-isolation-catalogs-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	path_a := os.join_path(dir, 'a.vsql')
	path_b := os.join_path(dir, 'b.vsql')
	// Each catalog of a connection needs its own mutex.
	options := isolation_test_options(0)
	options_b := isolation_test_options(0)

	mut a := open_database(path_a, options)!
	defer {
		a.close()
	}
	a.query('CREATE TABLE t (x INT)')!

	mut b := open_database(path_b, options)!
	defer {
		b.close()
	}
	b.query('CREATE TABLE t (x INT)')!

	mut both := open_database(path_a, options)!
	defer {
		both.close()
	}
	both.add_catalog('b', path_b, options_b)!

	// A READ COMMITTED transaction that changes both files can't commit while
	// b is locked, so the change to a is rolled back too.
	b.query('START TRANSACTION ISOLATION LEVEL SERIALIZABLE')!
	both.query('START TRANSACTION ISOLATION LEVEL READ COMMITTED')!
	both.query('INSERT INTO "a".public.t (x) VALUES (1)')!
	both.query('INSERT INTO "b".public.t (x) VALUES (2)')!
	assert query_error(mut both, 'COMMIT') == '40001 serialization failure: cannot commit while another connection has a REPEATABLE READ or SERIALIZABLE transaction'
	assert !both.in_transaction()
	assert a.query('SELECT * FROM t')!.rows.len == 0

	// Changing only a can still be committed, but a SERIALIZABLE statement on
	// its own waits for every file.
	both.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED')!
	both.query('INSERT INTO "a".public.t (x) VALUES (3)')!
	assert a.query('SELECT * FROM t')!.rows.len == 1
	assert query_error(mut both, 'INSERT INTO "a".public.t (x) VALUES (3)') == '40001 serialization failure: another connection has a transaction that must finish first'
	b.query('COMMIT')!

	// A SERIALIZABLE transaction locks both files.
	both.query('START TRANSACTION')!
	assert query_error(mut a, 'INSERT INTO t (x) VALUES (4)') != ''
	assert query_error(mut b, 'INSERT INTO t (x) VALUES (4)') != ''
	both.query('ROLLBACK')!
	a.query('INSERT INTO t (x) VALUES (4)')!
	b.query('INSERT INTO t (x) VALUES (4)')!

	// A catalog that is added during the transaction joins it, so it's locked
	// too.
	mut c := open_database(path_a, options)!
	defer {
		c.close()
	}
	c.query('START TRANSACTION ISOLATION LEVEL REPEATABLE READ')!
	b.query('INSERT INTO t (x) VALUES (5)')!
	c.add_catalog('b', path_b, options_b)!
	assert query_error(mut b, 'INSERT INTO t (x) VALUES (6)') != ''
	c.query('COMMIT')!
	b.query('INSERT INTO t (x) VALUES (6)')!
	assert b.query('SELECT * FROM t')!.rows.len == 3

	// A catalog can't join a transaction if it's locked.
	mut d := open_database(path_a, isolation_test_options(0))!
	defer {
		d.close()
	}
	b.query('START TRANSACTION')!
	d.query('START TRANSACTION')!
	mut got := ''
	d.add_catalog('b', path_b, isolation_test_options(0)) or { got = err.msg() }
	assert got == 'serialization failure: another connection has a transaction that must finish first'
	assert 'b' !in d.catalogs
	d.query('COMMIT')!
	b.query('COMMIT')!
}

// A SERIALIZABLE transaction waits for another connection's transaction to
// finish, rather than failing straight away.
fn test_isolation_waits() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-isolation-waits-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'test.vsql')
	options := isolation_test_options(5 * time.second)

	mut db := open_database(path, options)!
	defer {
		db.close()
	}
	db.query('CREATE TABLE t (x INT)')!
	db.query('START TRANSACTION')!
	db.query('INSERT INTO t (x) VALUES (1)')!

	// The other transaction starts once this one commits, so it sees its
	// changes. So does a statement on its own.
	other := spawn fn [path, options] () !(int, int) {
		mut db := open_database(path, options)!
		defer {
			db.close()
		}
		db.query('START TRANSACTION')!
		count := db.query('SELECT * FROM t')!.rows.len
		db.query('COMMIT')!
		db.query('INSERT INTO t (x) VALUES (2)')!
		return count, db.query('SELECT * FROM t')!.rows.len
	}()
	statement := spawn fn [path, options] () !int {
		mut db := open_database(path, options)!
		defer {
			db.close()
		}
		db.query('INSERT INTO t (x) VALUES (3)')!
		return db.query('SELECT * FROM t WHERE x = 1')!.rows.len
	}()
	time.sleep(50 * time.millisecond)
	db.query('INSERT INTO t (x) VALUES (4)')!
	db.query('COMMIT')!
	seen, total := other.wait()!
	assert seen in [2, 3]
	assert total >= 3
	assert statement.wait()! == 1

	// READ ONLY transactions don't wait for each other.
	db.query('START TRANSACTION READ ONLY')!
	reader := spawn fn [path] () !int {
		mut db := open_database(path, isolation_test_options(0))!
		defer {
			db.close()
		}
		db.query('START TRANSACTION READ ONLY')!
		count := db.query('SELECT * FROM t')!.rows.len
		db.query('COMMIT')!
		return count
	}()
	assert reader.wait()! == 4
	db.query('COMMIT')!

	// It gives up after the timeout.
	db.query('START TRANSACTION')!
	t := time.now()
	timeout := 30 * time.millisecond
	mut quick := open_database(path, isolation_test_options(timeout))!
	defer {
		quick.close()
	}
	assert query_error(mut quick, 'START TRANSACTION') == '40001 serialization failure: timed out after 30.000ms waiting for another connection to finish its transaction'
	assert time.since(t) >= timeout
	assert !quick.in_transaction()
	db.query('COMMIT')!
	quick.query('START TRANSACTION')!
	quick.query('COMMIT')!
}
