// flock_nix.c.v contains file locking functions. flock() !tself only protects
// against concurrent access from different processes, so to protect against
// goroutines we need to add an additional level of locking within this process.

module vsql

import os

#include <fcntl.h>

fn C.flock(int, int) int

fn flock_lock_exclusive(file os.File, path string) ! {
	C.flock(file.fd, C.LOCK_EX)
}

fn flock_lock_shared(file os.File, path string) ! {
	C.flock(file.fd, C.LOCK_SH)
}

fn flock_unlock_exclusive(file os.File, path string) {
	C.flock(file.fd, C.LOCK_UN)
}

fn flock_unlock_shared(file os.File, path string) {
	C.flock(file.fd, C.LOCK_UN)
}
