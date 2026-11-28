// file_identity_nix.c.v finds out if a file that is kept open is still the file
// at its path, see FileIdentity.

module vsql

import os

fn C.stat(&char, &C.stat) i32

// FileIdentity tells files apart, so that a file that is kept open between
// statements can be opened again if another process replaced or deleted it in
// the meantime (such as by restoring a backup).
struct FileIdentity {
	device u64
	inode  u64
}

// open_file_identity returns the identity of a file that is open. The stat
// buffer is allocated and freed with libc (so it's never in an arena, see
// arena_pause), since -autofree never frees a local whose address is taken
// (https://github.com/vlang/v/issues/32980).
@[manualfree]
fn open_file_identity(file os.File) FileIdentity {
	st := unsafe { &C.stat(C.calloc(1, sizeof(C.stat))) }
	defer {
		unsafe { C.free(st) }
	}
	C.fstat(file.fd, st)

	return FileIdentity{u64(st.st_dev), u64(st.st_ino)}
}

// path_file_identity returns the identity of the file at path, or none if it
// doesn't exist. It doesn't use os.stat, which leaks with -autofree (see open_file_identity).
@[manualfree]
fn path_file_identity(path string) ?FileIdentity {
	st := unsafe { &C.stat(C.calloc(1, sizeof(C.stat))) }
	defer {
		unsafe { C.free(st) }
	}
	if unsafe { C.stat(&char(path.str), st) } != 0 {
		return none
	}

	return FileIdentity{u64(st.st_dev), u64(st.st_ino)}
}

// file_replaced returns true if the open file is no longer the file at path.
// It's only needed here, since Windows doesn't let an open file be replaced.
fn (f Storage) file_replaced(path string) bool {
	identity := path_file_identity(path) or { return true }

	return identity != f.file_identity
}
