// flock.v contains file locking functions. This likely only works on *nix
// systems.

module vsql

import os

#include <fcntl.h>

fn C.flock(int, int) int

fn flock_lock_exclusive(f os.File) {
	C.flock(f.fd, C.LOCK_EX)
}

fn flock_lock_shared(f os.File) {
	C.flock(f.fd, C.LOCK_SH)
}

fn flock_unlock(f os.File) {
	C.flock(f.fd, C.LOCK_UN)
}
