// fault.v lets the SQL tests make an operation fail, such as writing to the
// disk, so that the code that handles the error can be tested. A test uses the
// "fault" directive, see "Faults" in docs/testing.rst.
//
// This is similar to crash_point() (see wal.v), except that it returns an error
// rather than stopping the process.

module vsql

// fault_names are the faults that can be armed. Each one is a fault_point() or
// fault_reached() call with that name:
//
//   open:              opening the database file.
//   lock:              locking the database file to write to it.
//   lock_shared:       locking the database file to read it.
//   read_header:       reading the header of the database file.
//   read_page:         reading a page from the database file.
//   write_version:     the file needs a newer version of vsql to be changed.
//   wal_write:         writing a statement to the write-ahead log, before it's
//                      committed.
//   wal_torn_frame:    only half of the commit frame is written to the
//                      write-ahead log, like a process that stopped while
//                      writing it.
//   wal_corrupt_frame: the commit frame in the write-ahead log has the wrong
//                      checksum, like a write that didn't reach the disk
//                      correctly.
//   wal_bad_magic:     the write-ahead log doesn't start with its magic number.
//   wal_bad_header:    the header of the write-ahead log has the wrong
//                      checksum.
//   wal_unknown_frame: the write-ahead log has a frame of an unknown kind.
//   checkpoint:        copying a committed statement from the write-ahead log
//                      into the database file.
//   recover:           copying a statement that was left in the write-ahead log
//                      into the database file.
//   isolation_start:   starting the isolation block of an operation on the
//                      file, see Storage.isolation_start.
//   isolation_end:     ending the isolation block of an operation on the file,
//                      which removes the rows that were deleted outside of a
//                      transaction, see Storage.isolation_end.
const fault_names = ['open', 'lock', 'lock_shared', 'read_header', 'read_page', 'write_version',
	'wal_write', 'wal_torn_frame', 'wal_corrupt_frame', 'wal_bad_magic', 'wal_bad_header',
	'wal_unknown_frame', 'checkpoint', 'recover', 'isolation_start', 'isolation_end']

struct FaultPoints {
mut:
	// armed is the number of times each fault must be reached before it fails.
	armed map[string]int
}

const fault_points = &FaultPoints{}

// arm_fault makes a fault fail the nth time it's reached (1 for the next time).
fn arm_fault(name string, nth int) ! {
	if name !in fault_names {
		return error('unknown fault: ${name}')
	}

	if nth < 1 {
		return error('fault ${name} must be reached at least once, not ${nth}')
	}

	mut f := unsafe { &FaultPoints(fault_points) }
	f.armed[name] = nth
}

// disarm_faults removes any faults that haven't been reached.
fn disarm_faults() {
	mut f := unsafe { &FaultPoints(fault_points) }
	f.armed = map[string]int{}
}

// fault_reached returns true when an armed fault is reached for the nth time.
// After that it is disarmed.
fn fault_reached(name string) bool {
	mut f := unsafe { &FaultPoints(fault_points) }
	if f.armed.len == 0 || name !in f.armed {
		return false
	}

	f.armed[name]--
	if f.armed[name] > 0 {
		return false
	}

	f.armed.delete(name)
	return true
}

// fault_point returns an error when an armed fault is reached for the nth time.
fn fault_point(name string) ! {
	if fault_reached(name) {
		return fault_error(name)
	}
}

fn fault_error(name string) IError {
	return error('${name} failed (fault injected by test)')
}
