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
// connection to the database. The last connection deletes the file (see
// CatalogConnection.remove_lock_files), so every lock is taken with
// lock_path_file.
struct SessionLock {
	path string
mut:
	file os.File
}

fn session_lock(path string) !SessionLock {
	mut l := SessionLock{
		path: path
	}
	lock_path_file(mut l.file, path, C.LOCK_SH)!

	return l
}

// try_exclusive returns true if the lock was converted to an exclusive lock.
// Use shared() to convert it back.
fn (mut l SessionLock) try_exclusive() !bool {
	// Converting a lock is not atomic, so the shared lock may have been lost,
	// and the last connection may have deleted the file in the meantime. The
	// lock is only the session lock if it's still the file at the path.
	if C.flock(l.file.fd, C.LOCK_EX | C.LOCK_NB) == 0 && lock_is_path_file(l.file, l.path) {
		return true
	}

	l.shared()!

	return false
}

fn (mut l SessionLock) shared() ! {
	fault_point('session_shared')!
	lock_path_file(mut l.file, l.path, C.LOCK_SH)!
}

// remove deletes the session file, which must be locked exclusively, see
// CatalogConnection.remove_lock_files. The lock is still held until close().
fn (mut l SessionLock) remove() {
	if lock_is_path_file(l.file, l.path) {
		os.rm(l.path) or {}
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
	operation := if state == .shared { C.LOCK_SH } else { C.LOCK_EX }
	if !lock_path_file(mut l.file, l.path, operation | C.LOCK_NB)! {
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

// lock_path_file locks the file at path with operation (for flock), opening
// it first if file isn't open, and creating it if it doesn't exist. It returns
// false if operation has LOCK_NB and the file can't be locked straight away.
//
// A lock file is deleted by the last connection to the database, while it
// holds the lock exclusively (see CatalogConnection.remove_lock_files). A
// connection that was waiting for the lock, or that opened the file before it
// was deleted, gets a lock on the deleted file, which isn't the lock that
// anyone else uses. So the lock only counts if the file is still the one at
// path. Otherwise, the deleted file is closed, and the new one at path is
// locked instead.
fn lock_path_file(mut file os.File, path string, operation int) !bool {
	for {
		if !file.is_opened {
			file = os.open_file(path, 'a') or {
				return sqlstate_58030('unable to open ${path}: ${err}')
			}
		}

		if C.flock(file.fd, operation) != 0 {
			if operation & C.LOCK_NB != 0 {
				return false
			}
			return sqlstate_58030('cannot acquire lock on ${path}: ${os.posix_get_error_msg(C.errno)}')
		}

		if lock_is_path_file(file, path) {
			break
		}

		C.flock(file.fd, C.LOCK_UN)
		file.close()
	}

	return true
}

// remove_lock_files deletes the lock files of the database file when the last
// connection to it is closed (see Connection.close), so that only the database
// file is left behind. Each one is deleted while it's locked exclusively, so a
// connection that gets a lock on a file after it's deleted knows to use the new
// file instead, see lock_path_file. The session file is deleted last.
fn (mut conn CatalogConnection) remove_lock_files() {
	isolation := isolation_path(conn.path)
	deferral := deferral_path(conn.path)
	// The copies work around https://github.com/vlang/v/issues/32947 (-autofree).
	for path in [own_string(isolation), isolation_queue_path(isolation), own_string(deferral),
		isolation_queue_path(deferral)] {
		remove_lock_file(path)
	}
	conn.storage.session.remove()
}

// remove_lock_file deletes a lock file, if it exists and no other connection
// has it locked. It's locked exclusively while it's deleted, see
// lock_path_file.
fn remove_lock_file(path string) {
	mut file := os.open_file(path, 'r') or { return }
	defer {
		file.close()
	}

	if C.flock(file.fd, C.LOCK_EX | C.LOCK_NB) == 0 && lock_is_path_file(file, path) {
		os.rm(path) or {}
	}
}

// lock_is_path_file returns true if the open file is still the file at path,
// see lock_path_file.
fn lock_is_path_file(file os.File, path string) bool {
	identity := path_file_identity(path) or { return false }

	return identity == open_file_identity(file)
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

// begin_precise_sleep and end_precise_sleep are only needed on Windows, where
// time.sleep() isn't precise to a millisecond.
fn begin_precise_sleep() {}

fn end_precise_sleep() {}
