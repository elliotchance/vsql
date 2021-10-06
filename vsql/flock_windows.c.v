// flock_windows.c.v contains file locking functions for windows.
//
// TODO(elliotchance): This isn't as reliable as the *nix version because it
//  uses an extra file which may still cause race conditions.

module vsql

import os
import os.filelock

fn flock_lock_exclusive(file os.File, path string) ? {
	mut f := filelock.new('${path}.lock')
	f.acquire() ?
}

fn flock_lock_shared(file os.File, path string) ? {
	mut f := filelock.new('${path}.lock')
	f.acquire() ?
}

fn flock_unlock_exclusive(file os.File, path string) {
	mut f := filelock.new('${path}.lock')
	f.release()
}

fn flock_unlock_shared(file os.File, path string) {
	mut f := filelock.new('${path}.lock')
	f.release()
}
