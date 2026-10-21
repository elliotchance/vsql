// wal.v implements the write-ahead log, which makes each statement that changes
// a database file atomic and durable. See "Write-Ahead Log" in the file format
// docs.

module vsql

import encoding.binary
import hash.crc32
import os
import rand

const wal_magic = 'vsqlwal\n'.bytes()

// wal_version is the version of the layout of the log file. It is separate
// from file_format_version because the log only exists for as long as a
// statement is being written.
const wal_version = u16(1)

const wal_header_size = 32

const wal_frame_header_size = 16

// wal_state_offset is the position of the state in the log header. It isn't
// covered by the checksum of the header because it's changed after the log has
// been written.
const wal_state_offset = 10

const wal_state_committed = u8(0)

const wal_state_checkpointed = u8(1)

const wal_frame_page = u8(1)

const wal_frame_commit = u8(2)

fn wal_path(path string) string {
	return '${path}.wal'
}

// wal_commit makes the changes of a statement permanent. The changed pages and
// the header are written to the log, which is synced to the disk. Then they
// are copied into the database file. If the process stops at any point, the
// database file can be fixed by wal_recover.
//
// It must only be called with the database file locked exclusively.
fn wal_commit(mut file os.File, path string, header Header, pager &FilePager) ! {
	mut page_numbers := pager.dirty.keys().filter(it < pager.total_pages)
	page_numbers.sort()

	mut pages := map[int][]u8{}
	for page_number in page_numbers {
		pages[page_number] = pager.dirty[page_number]
	}

	header_bytes := header.bytes()

	// The salt is the start of the chain of checksums. A new one is used for
	// each log so that frames left over from a previous log are never valid.
	salt := rand.u32()

	log_path := wal_path(path)
	is_new := !os.exists(log_path)
	mut log := os.create(log_path) or { return error('unable to create ${log_path}: ${err}') }
	defer {
		log.close()
	}

	log_header := wal_header(salt, pager.page_size)
	wal_corrupt_fault(mut log, log_header, salt)!
	log.write(log_header)!

	mut checksum := salt
	for page_number in page_numbers {
		crash_point()
		frame, frame_checksum := wal_frame(wal_frame_page, page_number, pages[page_number],
			checksum)
		log.write(frame)!
		checksum = frame_checksum
	}

	crash_point()
	fault_point('wal_write')!
	commit_frame, _ := wal_frame(wal_frame_commit, pager.total_pages, header_bytes, checksum)
	if fault_reached('wal_torn_frame') {
		log.write(commit_frame[..commit_frame.len / 2])!
		log.flush()
		return fault_error('wal_torn_frame')
	}
	if fault_reached('wal_corrupt_frame') {
		mut corrupt := commit_frame.clone()
		corrupt[corrupt.len - 1] ^= 0xff
		log.write(corrupt)!
		log.flush()
		return fault_error('wal_corrupt_frame')
	}
	log.write(commit_frame)!
	log.flush()
	fsync(log, log_path)!

	// A new file must also be synced in its directory, otherwise it may not
	// exist after a crash.
	if is_new {
		fsync_dir(os.dir(os.real_path(log_path)))!
	}

	// This is the point where the statement is committed, so the statement must
	// not fail after this. If the log can't be copied into the database file,
	// it's left as it is, and it's copied by wal_recover before the file is
	// read again (by the next statement or connection).
	crash_point()
	wal_checkpoint(mut file, path, pager.page_size, pages, header_bytes, pager.total_pages) or {
		return
	}

	// If this doesn't reach the disk, the log is copied into the database file
	// again (which doesn't change it) by wal_recover.
	log.seek(wal_state_offset, .start)!
	log.write([wal_state_checkpointed])!
}

// wal_corrupt_fault writes a log that is corrupt (and then returns an error) if
// a test has armed one of the faults for a corrupt log. The log looks like it
// has a committed statement, so it must be ignored by wal_recover.
fn wal_corrupt_fault(mut log os.File, header []u8, salt u32) ! {
	mut name := ''
	mut corrupt := header.clone()
	if fault_reached('wal_bad_magic') {
		name = 'wal_bad_magic'
		corrupt[0] ^= 0xff
	} else if fault_reached('wal_bad_header') {
		// The page size is covered by the checksum of the header.
		name = 'wal_bad_header'
		corrupt[12] ^= 0xff
	} else if fault_reached('wal_unknown_frame') {
		name = 'wal_unknown_frame'
		frame, _ := wal_frame(0xff, 0, []u8{}, salt)
		corrupt << frame
	} else {
		return
	}

	log.write(corrupt)!
	log.flush()

	return fault_error(name)
}

// wal_checkpoint copies the pages and header of a committed log into the
// database file.
fn wal_checkpoint(mut file os.File, path string, page_size int, pages map[int][]u8, header_bytes []u8, total_pages int) ! {
	fault_point('checkpoint')!

	for page_number, data in pages {
		crash_point()
		file.seek(i64(header_size) + i64(page_size) * page_number, .start)!
		file.write(data)!
	}

	crash_point()
	file.seek(0, .start)!
	file.write(header_bytes)!
	file.flush()

	truncate_file(file, path, u64(header_size) + u64(page_size) * u64(total_pages))!
	fsync(file, path)!
}

// wal_needs_recovery returns true if the log contains a statement that may not
// have been copied into the database file yet. It doesn't need a lock, but
// wal_recover does.
fn wal_needs_recovery(path string) bool {
	log_path := wal_path(path)
	if !os.exists(log_path) {
		return false
	}

	mut log := os.open(log_path) or { return true }
	defer {
		log.close()
	}

	mut header := []u8{len: wal_header_size}
	read := log.read(mut header) or { return true }

	return read == wal_header_size && header[wal_state_offset] != wal_state_checkpointed
}

// wal_recover copies a committed statement in the log into the database file,
// if it wasn't already. This happens when a process stops while it's writing
// to the database. A statement that wasn't committed (the log doesn't end with
// a valid commit frame) is ignored, because the database file wasn't changed.
//
// It must only be called with the database file locked exclusively.
fn wal_recover(mut file os.File, path string) ! {
	if !wal_needs_recovery(path) {
		return
	}
	fault_point('recover')!

	log_path := wal_path(path)
	data := os.read_bytes(log_path) or { return error('unable to read ${log_path}: ${err}') }

	if data.len >= wal_header_size && data[..wal_magic.len] == wal_magic {
		version := binary.big_endian_u16_at(data, wal_magic.len)
		if version > wal_version {
			return error('${log_path} uses version ${version} of the write-ahead log, but this version of vsql only supports up to ${wal_version}')
		}
	}

	if commit := wal_read(data) {
		wal_checkpoint(mut file, path, commit.page_size, commit.pages, commit.header_bytes,
			commit.total_pages)!
	}

	// The "b" is needed on Windows, otherwise the file is opened in text mode.
	mut log := os.open_file(log_path, 'rb+') or {
		return error('unable to open ${log_path}: ${err}')
	}
	defer {
		log.close()
	}
	log.seek(wal_state_offset, .start)!
	log.write([wal_state_checkpointed])!
}

struct WalCommit {
	page_size    int
	pages        map[int][]u8
	header_bytes []u8
	total_pages  int
}

// wal_read returns the last committed statement in the log, or none if there
// isn't one. Reading stops at the first frame that isn't valid, which is where
// a process stopped while writing the log.
fn wal_read(data []u8) ?WalCommit {
	if data.len < wal_header_size || data[..wal_magic.len] != wal_magic {
		return none
	}

	mut header := data[..wal_header_size].clone()
	header[wal_state_offset] = 0
	if crc32.sum(header[..wal_header_size - 4]) != binary.big_endian_u32_at(header, wal_header_size - 4) {
		return none
	}

	page_size := int(binary.big_endian_u32_at(data, 12))
	salt := binary.big_endian_u32_at(data, 16)

	mut pages := map[int][]u8{}
	mut commit := ?WalCommit(none)
	mut checksum := salt
	mut offset := wal_header_size
	for offset + wal_frame_header_size <= data.len {
		kind := data[offset]
		number := int(binary.big_endian_u32_at(data, offset + 4))
		len := int(binary.big_endian_u32_at(data, offset + 8))
		frame_checksum := binary.big_endian_u32_at(data, offset + 12)
		start := offset + wal_frame_header_size
		if len < 0 || start + len > data.len {
			break
		}

		frame_data := data[start..start + len]
		if wal_checksum(checksum, data[offset..offset + 12], frame_data) != frame_checksum {
			break
		}

		checksum = frame_checksum
		offset = start + len

		match kind {
			wal_frame_page {
				pages[number] = frame_data.clone()
			}
			wal_frame_commit {
				commit = WalCommit{page_size, pages.clone(), frame_data.clone(), number}
			}
			else {
				break
			}
		}
	}

	return commit
}

fn wal_header(salt u32, page_size int) []u8 {
	mut header := []u8{len: wal_header_size}
	for i, b in wal_magic {
		header[i] = b
	}
	binary.big_endian_put_u16_at(mut header, wal_version, wal_magic.len)
	header[wal_state_offset] = wal_state_committed
	binary.big_endian_put_u32_at(mut header, u32(page_size), 12)
	binary.big_endian_put_u32_at(mut header, salt, 16)
	binary.big_endian_put_u32_at(mut header, crc32.sum(header[..wal_header_size - 4]),
		wal_header_size - 4)

	return header
}

// wal_frame returns the bytes of a frame and its checksum, which continues the
// chain from the previous frame (or the salt for the first frame).
fn wal_frame(kind u8, number int, data []u8, previous_checksum u32) ([]u8, u32) {
	mut frame := []u8{len: wal_frame_header_size}
	frame[0] = kind
	binary.big_endian_put_u32_at(mut frame, u32(number), 4)
	binary.big_endian_put_u32_at(mut frame, u32(data.len), 8)
	checksum := wal_checksum(previous_checksum, frame[..12], data)
	binary.big_endian_put_u32_at(mut frame, checksum, 12)
	frame << data

	return frame, checksum
}

fn wal_checksum(previous_checksum u32, frame_header []u8, data []u8) u32 {
	mut b := binary.big_endian_get_u32(previous_checksum)
	b << frame_header
	b << data

	return crc32.sum(b)
}

// crash_point stops the process, without flushing any files, when it has been
// reached the number of times in the VSQL_CRASH_AT environment variable. It's
// only used to test that a database can be recovered when a process stops
// while it's writing.
fn crash_point() {
	mut state := unsafe { &CrashPoint(crash_point_state) }
	if state.at == 0 {
		return
	}

	state.count++
	if state.count == state.at {
		C._exit(1)
	}
}

fn C._exit(int)

struct CrashPoint {
	at int
mut:
	count int
}

const crash_point_state = &CrashPoint{
	at: os.getenv('VSQL_CRASH_AT').int()
}
