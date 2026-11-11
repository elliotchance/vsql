// flock_windows.c.v contains file locking functions for windows.

module vsql

import os
import os.filelock

// DataFileLock is the lock held on the database file while it's being read or
// written. Windows locks are mandatory, so locking the database file itself
// would also stop it being read and written through the other handle. Instead,
// the lock is held on a separate file next to it.
struct DataFileLock {
mut:
	lock filelock.FileLock
}

fn flock_lock_exclusive(mut l DataFileLock, _ os.File, path string) ! {
	fault_point('lock')!
	l.lock = lock_data_file(path, .exclusive)!
}

fn flock_lock_shared(mut l DataFileLock, _ os.File, path string) ! {
	fault_point('lock_shared')!
	l.lock = lock_data_file(path, .shared)!
}

fn flock_unlock_exclusive(mut l DataFileLock, _ os.File, _ string) {
	l.lock.release()
}

fn flock_unlock_shared(mut l DataFileLock, _ os.File, _ string) {
	l.lock.release()
}

fn lock_data_file(path string, mode filelock.LockMode) !filelock.FileLock {
	lock_path := '${path}.lock'

	// Make sure the file exists without truncating it.
	mut file := os.open_append(lock_path) or {
		return sqlstate_58030('unable to open ${lock_path}: ${err}')
	}
	file.close()

	mut l := filelock.new_file(lock_path, mode: mode)
	l.acquire() or { return sqlstate_58030('cannot acquire lock on ${lock_path}: ${err}') }

	return l
}

// SessionLock is a shared lock held on the session file for as long as a
// connection is open. The operating system releases it when the process dies,
// so a connection that can get it exclusively knows that it is the only
// connection to the database.
struct SessionLock {
	path string
mut:
	lock filelock.FileLock
}

fn session_lock(path string) !SessionLock {
	// Make sure the file exists without truncating it.
	mut file := os.open_append(path) or { return sqlstate_58030('unable to open ${path}: ${err}') }
	file.close()

	mut l := SessionLock{
		path: path
		lock: filelock.new_file(path, mode: .shared)
	}
	l.lock.acquire() or { return sqlstate_58030('cannot acquire lock on ${path}: ${err}') }

	return l
}

// try_exclusive returns true if the lock was converted to an exclusive lock.
// Use shared() to convert it back.
fn (mut l SessionLock) try_exclusive() !bool {
	l.lock.release()
	l.lock = filelock.new_file(l.path, mode: .exclusive)
	if l.lock.try_acquire() {
		return true
	}

	l.shared()!

	return false
}

fn (mut l SessionLock) shared() ! {
	fault_point('session_shared')!
	l.lock.release()
	l.lock = filelock.new_file(l.path, mode: .shared)
	l.lock.acquire() or { return sqlstate_58030('cannot acquire session lock: ${err}') }
}

// close releases the lock.
fn (mut l SessionLock) close() {
	l.lock.release()
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

@[typedef]
struct C.OVERLAPPED {}

fn C.LockFileEx(voidptr, u32, u32, u32, u32, &C.OVERLAPPED) bool
fn C.UnlockFileEx(voidptr, u32, u32, u32, &C.OVERLAPPED) bool

// try_lock gets the lock, which must not be held yet. It returns false if
// another connection holds a lock that conflicts.
fn (mut l IsolationLock) try_lock(state IsolationLockState) !bool {
	fault_point('isolation_lock')!
	if !l.file.is_opened {
		l.file = os.open_file(l.path, 'a') or {
			return sqlstate_58030('unable to open ${l.path}: ${err}')
		}
	}

	// The whole file (and beyond) is locked, from the start.
	mut flags := u32(C.LOCKFILE_FAIL_IMMEDIATELY)
	if state == .exclusive {
		flags |= u32(C.LOCKFILE_EXCLUSIVE_LOCK)
	}
	mut overlapped := C.OVERLAPPED{}
	if !C.LockFileEx(voidptr(C._get_osfhandle(l.file.fd)), flags, 0, max_u32, max_u32,
		&overlapped) {
		return false
	}
	l.state = state

	return true
}

// release unlocks the lock, if it's held. The file stays open.
fn (mut l IsolationLock) release() {
	if l.state != .unlocked {
		mut overlapped := C.OVERLAPPED{}
		C.UnlockFileEx(voidptr(C._get_osfhandle(l.file.fd)), 0, max_u32, max_u32, &overlapped)
	}
	l.state = .unlocked
}

// close_file closes the file, if it's open. The lock must be released first.
fn (mut l IsolationLock) close_file() {
	l.file.close()
}

#include <io.h>

// V's C for clang on Windows (such as llvm-mingw, which is used on ARM64)
// doesn't include stdio.h, and defines _IONBF and _IOLBF itself, with values
// that the Universal C Runtime rejects. V's runtime calls setvbuf with
// _IONBF when it starts, which ends the program, or the program that loads
// libvsql.dll. These are the values from stdio.h, which V's C only replaces if
// they aren't defined.
#flag -D_IONBF=4 -D_IOLBF=64

fn C._commit(int) int

// fsync waits for the file to be written to the disk. It must be flushed first.
// _commit() already asks the drive to write its cache, so ConnectionOptions.
// full_fsync makes no difference.
fn fsync(file os.File, path string, _ bool) ! {
	if C._commit(file.fd) != 0 {
		return sqlstate_58030('cannot fsync ${path}')
	}
}

// fsync_dir does nothing on Windows, where changes to the entries of a
// directory don't need to be synced separately.
fn fsync_dir(_ string) ! {
}

// truncate_file changes the size of a file that is open. It must be flushed
// first.
fn truncate_file(file os.File, path string, len u64) ! {
	if C._chsize_s(file.fd, len) != 0 {
		return sqlstate_58030('cannot truncate ${path}')
	}
}
