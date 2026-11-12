// flock_nix.c.v contains file locking functions. flock() !tself only protects
// against concurrent access from different processes, so to protect against
// goroutines we need to add an additional level of locking within this process.

module vsql

import os

#include <fcntl.h>
#include <sys/file.h>

fn C.flock(int, int) int

// DataFileLock is only needed on Windows. flock() holds the lock on the open
// file itself.
struct DataFileLock {}

fn flock_lock_exclusive(mut _ DataFileLock, file os.File, path string) ! {
	fault_point('lock')!
	if C.flock(file.fd, C.LOCK_EX) != 0 {
		return sqlstate_58030('cannot acquire lock on ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}

fn flock_lock_shared(mut _ DataFileLock, file os.File, path string) ! {
	fault_point('lock_shared')!
	if C.flock(file.fd, C.LOCK_SH) != 0 {
		return sqlstate_58030('cannot acquire lock on ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}

fn flock_unlock_exclusive(mut _ DataFileLock, file os.File, _ string) {
	C.flock(file.fd, C.LOCK_UN)
}

fn flock_unlock_shared(mut _ DataFileLock, file os.File, _ string) {
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
	file := os.open_file(path, 'a') or { return sqlstate_58030('unable to open ${path}: ${err}') }
	if C.flock(file.fd, C.LOCK_SH) != 0 {
		return sqlstate_58030('cannot acquire lock on ${path}: ${os.posix_get_error_msg(C.errno)}')
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
	fault_point('session_shared')!
	if C.flock(l.file.fd, C.LOCK_SH) != 0 {
		return sqlstate_58030('cannot acquire session lock: ${os.posix_get_error_msg(C.errno)}')
	}
}

// close releases the lock by closing the file.
fn (mut l SessionLock) close() {
	l.file.close()
}

// IsolationLock is held on the isolation file by REPEATABLE READ and
// SERIALIZABLE transactions, and by a statement that commits changes. See
// isolation.v. The file is opened the first time it's locked, and is kept open
// until close() so that each statement doesn't have to open it again.
struct IsolationLock {
	path string
mut:
	file  os.File
	state IsolationLockState
	// queue is the lock that's taken in turns to wait for this one, see
	// acquire.
	queue &IsolationLock = unsafe { nil }
}

// try_lock gets the lock, which must not be held yet. It returns false if
// another connection holds a lock that conflicts.
fn (mut l IsolationLock) try_lock(state IsolationLockState) !bool {
	fault_point('isolation_lock')!
	if !l.file.is_opened {
		l.file = os.open_file(l.path, 'a') or {
			return sqlstate_58030('unable to open ${l.path}: ${err}')
		}
	}

	operation := if state == .shared { C.LOCK_SH } else { C.LOCK_EX }
	if C.flock(l.file.fd, operation | C.LOCK_NB) != 0 {
		return false
	}
	l.state = state

	return true
}

// release unlocks the lock, if it's held. The file stays open.
fn (mut l IsolationLock) release() {
	if l.state != .unlocked {
		C.flock(l.file.fd, C.LOCK_UN)
	}
	l.state = .unlocked
}

// close_file closes the file, if it's open. The lock must be released first.
fn (mut l IsolationLock) close_file() {
	l.file.close()
}

fn C.fsync(int) int

// fsync waits for the file to be written to the disk. It must be flushed first.
//
// On macOS, fsync() only hands the data to the drive, which may keep it in its
// cache for a while, so it can still be lost if the power fails. If full is
// true, F_FULLFSYNC also asks the drive to write its cache to permanent storage
// (see ConnectionOptions.full_fsync). On other systems fsync() already does
// that, so full makes no difference.
fn fsync(file os.File, path string, full bool) ! {
	$if macos {
		if full {
			if C.fcntl(file.fd, C.F_FULLFSYNC) == -1 {
				return sqlstate_58030('cannot fsync ${path}: ${os.posix_get_error_msg(C.errno)}')
			}
			return
		}
	}

	if C.fsync(file.fd) != 0 {
		return sqlstate_58030('cannot fsync ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}

// fsync_dir waits for a change to the entries of a directory (such as creating
// a file) to be written to the disk. It doesn't use F_FULLFSYNC (see fsync)
// because the log is always synced after it, which also writes the cache of the
// drive.
fn fsync_dir(path string) ! {
	fd := C.open(&char(path.str), C.O_RDONLY)
	if fd < 0 {
		return sqlstate_58030('cannot open ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
	defer {
		C.close(fd)
	}

	if C.fsync(fd) != 0 {
		return sqlstate_58030('cannot fsync ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}

// truncate_file changes the size of a file that is open. It must be flushed
// first.
fn truncate_file(file os.File, path string, len u64) ! {
	if C.ftruncate(file.fd, len) != 0 {
		return sqlstate_58030('cannot truncate ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}
