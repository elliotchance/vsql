// file_identity_nix.c.v finds out if a file that is kept open is still the file
// at its path, see FileIdentity.

module vsql

import os

// FileIdentity tells files apart, so that a file that is kept open between
// statements can be opened again if another process replaced or deleted it in
// the meantime (such as by restoring a backup).
struct FileIdentity {
	device u64
	inode  u64
}

// open_file_identity returns the identity of a file that is open.
fn open_file_identity(file os.File) FileIdentity {
	mut st := C.stat{}
	C.fstat(file.fd, &st)

	return FileIdentity{u64(st.st_dev), u64(st.st_ino)}
}

// path_file_identity returns the identity of the file at path, or none if it
// doesn't exist.
fn path_file_identity(path string) ?FileIdentity {
	st := os.stat(path) or { return none }

	return FileIdentity{st.dev, st.inode}
}
