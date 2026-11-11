// isolation.v implements the SERIALIZABLE isolation level.
//
// Each statement only sees changes that were committed before it started (see
// object_is_visible), which is READ COMMITTED. A REPEATABLE READ transaction
// sees the snapshot that it took when it started instead (see
// Storage.take_snapshot), so other transactions can still commit while it's
// active.
//
// A snapshot isn't serializable: two transactions can each read something that
// the other one changes (write skew). So a SERIALIZABLE transaction doesn't
// allow any other transaction to commit until it has finished. That's done
// with a lock on the isolation file (the database file name followed by
// ".isolation"):
//
// - A READ WRITE transaction holds the lock exclusively until it ends, so only
//   one of them can be active at a time. A statement that changes the database
//   outside of a transaction is a transaction of its own, so it holds the lock
//   exclusively until it ends too.
// - A READ ONLY transaction holds a shared lock, so several of them can be
//   active at the same time.
// - If the lock is held by another connection, they wait up to lock_timeout
//   (see ConnectionOptions) for it, before failing with 40001 (serialization
//   failure). They wait before the database file is locked, so the transaction
//   that holds the lock can still run its statements.
// - To wait, a connection polls, and the operating system doesn't keep a queue
//   of those. A connection that releases the lock and needs it again takes it
//   back long before anything polling can notice, so it would keep the lock
//   until its work is finished, and everything else would run out of time. So
//   they first take turns on a second lock (the isolation file followed by
//   ".queue"), which is only held until the first lock is obtained, by the one
//   connection that's next. Which one is next is left to chance, rather than the
//   order they arrived, but it can't be the one that's holding the lock.
//
// That makes the transaction serializable: nothing is committed while it's
// active, so it runs as if it came after every transaction that committed
// before it started, and before every transaction that commits after it ends.
//
// A READ COMMITTED (or READ UNCOMMITTED) or REPEATABLE READ transaction doesn't
// take the lock, but committing its changes needs the lock exclusively, until
// the end of the statement. The database file is already locked by then, so it
// can't wait: it fails with 40001 straight away, and the transaction is rolled
// back. Uncommitted changes from other transactions are already invisible, and
// changing the same row in two transactions is already a 40001, so READ
// COMMITTED and REPEATABLE READ transactions can still read and write while the
// lock is held. They just can't commit. If the isolation file doesn't exist, no
// transaction can be holding a lock on it, so it isn't created just to commit.
//
// A query through Connection.direct that starts an SQL-transaction doesn't take
// the lock, since that isn't possible for a database that can only be read. It
// also means that readers don't wait for each other, or stop anything from
// committing. It's still isolated, because a query that would see something that
// was committed since the first query of the transaction fails instead, see
// check_direct_query. That includes a REPEATABLE READ transaction, which doesn't
// take its snapshot until it's started in storage.

module vsql

import os
import time

enum IsolationLockState {
	unlocked
	shared
	exclusive
}

// isolation_path is the file that is locked by SERIALIZABLE transactions on the
// database at path.
fn isolation_path(path string) string {
	return '${path}.isolation'
}

// isolation_queue_path is the file that is locked by the connection that's next
// to get the lock on the isolation file at path.
fn isolation_queue_path(path string) string {
	return '${path}.queue'
}

// acquire gets the lock, waiting up to timeout if another connection holds a
// lock that conflicts. Otherwise, it fails with a serialization failure with
// message. A lock that is already held by this connection is kept as it is. A
// database in memory can only be used by one connection, so it's never locked.
fn (mut l IsolationLock) acquire(state IsolationLockState, timeout time.Duration, message string) ! {
	if l.path == '' || l.state != .unlocked {
		return
	}

	// Without a timeout it's only one attempt, so it doesn't wait for a turn.
	if timeout <= 0 {
		if !l.try_lock(state)! {
			return sqlstate_40001(message)
		}
		return
	}

	deadline := time.now().add(timeout)
	if isnil(l.queue) {
		l.queue = &IsolationLock{
			path: isolation_queue_path(l.path)
		}
	}
	l.queue.wait(.exclusive, deadline, message)!
	defer {
		l.queue.release()
	}
	l.wait(state, deadline, message)!
}

// close releases the lock and closes its files, which are otherwise kept open
// for as long as the connection, so that they don't have to be opened for each
// statement. It must be called when the connection is closed.
fn (mut l IsolationLock) close() {
	l.release()
	l.close_file()
	if !isnil(l.queue) {
		l.queue.close()
	}
}

// wait polls for the lock until the deadline.
fn (mut l IsolationLock) wait(state IsolationLockState, deadline time.Time, message string) ! {
	for !l.try_lock(state)! {
		if time.now() >= deadline {
			return sqlstate_40001(message)
		}
		time.sleep(time.millisecond)
	}
}

// lock_transaction must be called before a SERIALIZABLE transaction starts,
// before any database file is locked. The catalogs are locked in the same order
// by every connection, so two connections can't wait for each other.
fn (mut conn Connection) lock_transaction(read_only bool) ! {
	mut catalogs := conn.catalogs.values()
	catalogs.sort(a.path < b.path)
	for mut catalog in catalogs {
		catalog.lock_transaction(read_only)!
	}
}

fn (mut catalog CatalogConnection) lock_transaction(read_only bool) ! {
	timeout := catalog.options.lock_timeout
	catalog.storage.isolation.acquire(if read_only { .shared } else { .exclusive }, timeout,
		if timeout > 0 {
			'timed out after ${timeout} waiting for another connection to finish its transaction'
		} else {
			'another connection has a transaction that must finish first'
		})!
}

// check_direct_query must be called after each query of an SQL-transaction that
// hasn't been started in storage (see Connection.direct), and after it has been
// started by the statement that follows them. The header is what that statement
// read, while the database file was locked, so nothing can be committed between
// them. A REPEATABLE READ or SERIALIZABLE transaction that can't be isolated any
// more is rolled back with a serialization failure, which has nothing to undo.
//
// ISO/IEC 9075-2:2016(E), 4.41.5, Implicit rollbacks
fn (mut conn Connection) check_direct_query() ! {
	if conn.isolation_level !in [.repeatable_read, .serializable] {
		return
	}

	for name, catalog in conn.catalogs {
		// Only one connection can use a database in memory.
		if catalog.path == ':memory:' {
			continue
		}

		before := conn.direct_query_headers[name] or {
			conn.direct_query_headers[name] = catalog.storage.header
			continue
		}
		if catalog.storage.header.has_ended_since(before) {
			conn.direct_query_transaction = false
			return sqlstate_40001('another connection has committed since this transaction started reading')
		}
	}
}

// has_ended_since is true if a transaction that was active at the time of the
// before header, or has started since, is no longer active. The file doesn't
// show whether it was committed or rolled back, so a rollback counts too.
fn (h Header) has_ended_since(before Header) bool {
	mut active := h.active_transaction_ids
	for tid in before.active_transaction_ids.tids {
		if tid != 0 && !active.exists(tid) {
			return true
		}
	}

	// Each ID is checked until the first that isn't active, and at most 256 can
	// be active, so this doesn't take long even if a lot has happened.
	for tid := before.transaction_id + 1; tid <= h.transaction_id; tid++ {
		if !active.exists(tid) {
			return true
		}
	}

	return false
}

// unlock_transactions must be called at the end of every statement. The lock is
// released, unless the transaction is still active.
fn (mut conn Connection) unlock_transactions() {
	for _, mut catalog in conn.catalogs {
		catalog.storage.commit_locked = false
		if catalog.storage.transaction_state != .active {
			catalog.storage.isolation.release()
		}
	}
}

// lock_commit must be called before a READ COMMITTED or REPEATABLE READ
// transaction (or a statement on its own) makes its changes visible to other
// transactions. The lock is kept until the end of the statement, see
// unlock_transactions. It's only called while commit_locked is false, so that a
// page isn't read to find out if it needs the lock when it's already held.
fn (mut f Storage) lock_commit() ! {
	f.commit_locked = true

	if f.isolation.file.is_opened || os.exists(f.isolation.path) {
		f.isolation.acquire(.exclusive, 0, 'cannot commit while another connection has a SERIALIZABLE transaction')!
	}
}
