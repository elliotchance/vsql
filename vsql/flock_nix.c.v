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

fn C.fsync(int) int

// fsync waits for the file to be written to the disk. It must be flushed first.
fn fsync(file os.File, path string) ! {
	if C.fsync(file.fd) != 0 {
		return sqlstate_58030('cannot fsync ${path}: ${os.posix_get_error_msg(C.errno)}')
	}
}

// fsync_dir waits for a change to the entries of a directory (such as creating
// a file) to be written to the disk.
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
