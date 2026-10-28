// isolation.v implements the REPEATABLE READ and SERIALIZABLE isolation levels.
//
// Each statement only sees changes that were committed before it started (see
// object_is_visible), which is READ COMMITTED. A REPEATABLE READ or
// SERIALIZABLE transaction must also not see changes that other transactions
// commit after it has started. Instead of keeping a snapshot, no other
// transaction is allowed to commit until it has finished. That's done with a
// lock on the isolation file (the database file name followed by
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
//
// That makes the transaction serializable: nothing is committed while it's
// active, so it runs as if it came after every transaction that committed
// before it started, and before every transaction that commits after it ends.
//
// A READ COMMITTED (or READ UNCOMMITTED) transaction doesn't take the lock, but
// committing its changes needs the lock exclusively, until the end of the
// statement. The database file is already locked by then, so it can't wait:
// it fails with 40001 straight away, and the transaction is rolled back.
// Uncommitted changes from other transactions are already invisible, and
// changing the same row in two transactions is already a 40001, so READ
// COMMITTED transactions can still read and write while the lock is held. They
// just can't commit. If the isolation file doesn't exist, no transaction can be
// holding a lock on it, so it isn't created just to commit.

module vsql

import os
import time

enum IsolationLockState {
	unlocked
	shared
	exclusive
}

// isolation_path is the file that is locked by REPEATABLE READ and
// SERIALIZABLE transactions on the database at path.
fn isolation_path(path string) string {
	return '${path}.isolation'
}

// acquire gets the lock, waiting up to timeout if another connection holds a
// lock that conflicts. Otherwise, it fails with a serialization failure with
// message. A lock that is already held by this connection is kept as it is. A
// database in memory can only be used by one connection, so it's never locked.
fn (mut l IsolationLock) acquire(state IsolationLockState, timeout time.Duration, message string) ! {
	if l.path == '' || l.state != .unlocked {
		return
	}

	deadline := time.now().add(timeout)
	for !l.try_lock(state)! {
		if time.now() >= deadline {
			return sqlstate_40001(message)
		}
		time.sleep(time.millisecond)
	}
}

// lock_transaction must be called before a REPEATABLE READ or SERIALIZABLE
// transaction starts, before any database file is locked. The catalogs are
// locked in the same order by every connection, so two connections can't wait
// for each other.
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

// lock_commit must be called before a READ COMMITTED transaction (or a
// statement on its own) makes its changes visible to other transactions. The
// lock is kept until the end of the statement, see unlock_transactions.
fn (mut f Storage) lock_commit() ! {
	if f.commit_locked {
		return
	}
	f.commit_locked = true

	if os.exists(f.isolation.path) {
		f.isolation.acquire(.exclusive, 0, 'cannot commit while another connection has a REPEATABLE READ or SERIALIZABLE transaction')!
	}
}
