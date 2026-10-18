// flock_nix.c.v contains file locking functions. flock() !tself only protects
// against concurrent access from different processes, so to protect against
// goroutines we need to add an additional level of locking within this process.

module vsql

import os

#include <fcntl.h>

fn C.flock(int, int) int

fn flock_lock_exclusive(file os.File, path string) ! {
	if C.flock(file.fd, C.LOCK_EX) != 0 {
		return error('cannot acquire lock on ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}

fn flock_lock_shared(file os.File, path string) ! {
	if C.flock(file.fd, C.LOCK_SH) != 0 {
		return error('cannot acquire lock on ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}

fn flock_unlock_exclusive(file os.File, path string) {
	C.flock(file.fd, C.LOCK_UN)
}

fn flock_unlock_shared(file os.File, path string) {
	C.flock(file.fd, C.LOCK_UN)
}

// SessionLock is a shared lock held on the session file for as long as a
// connection is open. The operating system releases it when the process dies,
// so a connection that can get it exclusively knows that it is the only
// connection to the database.
struct SessionLock {
mut:
	file os.File
}

fn session_lock(path string) !SessionLock {
	file := os.open_file(path, 'a') or { return error('unable to open ${path}: ${err}') }
	if C.flock(file.fd, C.LOCK_SH) != 0 {
		return error('cannot acquire lock on ${path}: ${os.posix_get_error_msg(C.errno)}')
	}

	return SessionLock{file}
}

// try_exclusive returns true if the lock was converted to an exclusive lock.
// Use shared() to convert it back.
fn (mut l SessionLock) try_exclusive() !bool {
	if C.flock(l.file.fd, C.LOCK_EX | C.LOCK_NB) == 0 {
		return true
	}

	// Converting a lock is not atomic, so the shared lock may have been lost.
	l.shared()!

	return false
}

fn (mut l SessionLock) shared() ! {
	if C.flock(l.file.fd, C.LOCK_SH) != 0 {
		return error('cannot acquire session lock: ${os.posix_get_error_msg(C.errno)}')
	}
}
