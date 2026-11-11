// file_identity_windows.c.v finds out if a file that is kept open is still the
// file at its path, see FileIdentity.

module vsql

import os

// FileIdentity tells files apart, so that a file that is kept open between
// statements can be opened again if another process replaced or deleted it in
// the meantime. Windows doesn't let a file that is open be replaced or deleted
// (it isn't opened with FILE_SHARE_DELETE), so every file that exists is the
// same one.
struct FileIdentity {}

fn open_file_identity(_ os.File) FileIdentity {
	return FileIdentity{}
}

fn path_file_identity(path string) ?FileIdentity {
	return if os.exists(path) { FileIdentity{} } else { none }
}
