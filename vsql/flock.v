// flock.v contains file locking functions. flock() itself only protects against
// concurrent access from different processes, so to protect against goroutines
// we need to add an additional level of locking within this process.
//
// TODO(elliotchance) This likely only works on *nix systems.

module vsql

import os

#include <fcntl.h>

fn C.flock(int, int) int

fn flock_lock_exclusive(file os.File) {
	C.flock(file.fd, C.LOCK_EX)
}

fn flock_lock_shared(file os.File) {
	C.flock(file.fd, C.LOCK_SH)
}

fn flock_unlock_exclusive(file os.File) {
	C.flock(file.fd, C.LOCK_UN)
}

fn flock_unlock_shared(file os.File) {
	C.flock(file.fd, C.LOCK_UN)
}
