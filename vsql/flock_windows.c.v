// flock_windows.c.v contains file locking functions for windows.
//
// TODO(elliotchance): This isn't as reliable as the *nix version because it
//  uses an extra file which may still cause race conditions.

module vsql

import os
import os.filelock

fn flock_lock_exclusive(file os.File, path string) ! {
	mut f := filelock.new('${path}.lock')
	f.acquire() or { return error('cannot acquire lock: ${err}') }
}

fn flock_lock_shared(file os.File, path string) ! {
	mut f := filelock.new('${path}.lock')
	f.acquire() or { return error('cannot acquire lock: ${err}') }
}

fn flock_unlock_exclusive(file os.File, path string) {
	mut f := filelock.new('${path}.lock')
	f.release()
}

fn flock_unlock_shared(file os.File, path string) {
	mut f := filelock.new('${path}.lock')
	f.release()
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
	mut file := os.open_append(path) or { return error('unable to open ${path}: ${err}') }
	file.close()

	mut l := SessionLock{
		path: path
		lock: filelock.new_file(path, mode: .shared)
	}
	l.lock.acquire() or { return error('cannot acquire lock on ${path}: ${err}') }

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
	l.lock.release()
	l.lock = filelock.new_file(l.path, mode: .shared)
	l.lock.acquire() or { return error('cannot acquire session lock: ${err}') }
}

#include <io.h>

fn C._commit(int) int

// fsync waits for the file to be written to the disk. It must be flushed first.
fn fsync(file os.File, path string) ! {
	if C._commit(file.fd) != 0 {
		return error('cannot fsync ${path}')
	}
}

// fsync_dir does nothing on Windows, where changes to the entries of a
// directory don't need to be synced separately.
fn fsync_dir(path string) ! {
}

// truncate_file changes the size of a file that is open. It must be flushed
// first.
fn truncate_file(file os.File, path string, len u64) ! {
	if C._chsize_s(file.fd, len) != 0 {
		return error('cannot truncate ${path}')
	}
}
