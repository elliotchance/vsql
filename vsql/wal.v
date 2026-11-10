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
// from file_format_version because the log is only needed until its statements
// have been synced in the database file.
const wal_version = u16(2)

const wal_header_size = 32

const wal_frame_header_size = 16

// wal_state_offset, wal_tail_offset and wal_tail_checksum_offset are the
// positions in the log header that change as statements are added, so they
// aren't covered by the checksum of the header.
const wal_state_offset = 10

const wal_tail_offset = 20

const wal_tail_checksum_offset = 24

// wal_max_size is the size that a log starts again at, because everything in the
// log has to be copied after the power fails. A single statement can be larger.
const wal_max_size = 4 * 1024 * 1024

const wal_state_committed = u8(0)

const wal_state_checkpointed = u8(1)

const wal_frame_page = u8(1)

const wal_frame_commit = u8(2)

fn wal_path(path string) string {
	return '${path}.wal'
}

// wal_commit makes the changes of a statement permanent. The changed pages and
// the header are added to the log, which is synced to the disk. Then they are
// copied into the database file, without syncing it, because the log still has
// them. If the process stops or the power fails at any point, the database file
// can be fixed by wal_recover or wal_replay.
//
// It must only be called with the database file locked exclusively, and after
// wal_recover.
fn wal_commit(mut file os.File, path string, header Header, pager &FilePager) ! {
	mut page_numbers := pager.dirty.keys().filter(it < pager.total_pages)
	page_numbers.sort()

	header_bytes := header.bytes()

	mut pages := map[int][]u8{}
	mut size := wal_frame_header_size + header_bytes.len
	for page_number in page_numbers {
		pages[page_number] = pager.dirty[page_number]
		size += wal_frame_header_size + pages[page_number].len
	}

	log_path := wal_path(path)
	is_new := !os.exists(log_path)
	// A log is reused because replacing it takes longer. Frames left over from
	// the previous log are never valid, because each log has a new salt.
	mut log := if is_new {
		os.create(log_path) or { return sqlstate_58030('unable to create ${log_path}: ${err}') }
	} else {
		// The "b" is needed on Windows, otherwise the file is opened in text mode.
		os.open_file(log_path, 'rb+') or { return sqlstate_58030('unable to open ${log_path}: ${err}') }
	}
	defer {
		log.close()
	}

	mut salt, mut tail, mut checksum := wal_tail(mut log, pager.page_size)
	if tail == 0 || tail + size > wal_max_size {
		// The statements in the log are about to be lost, so the database file
		// must have them. The new header has to be on the disk before its frames
		// replace the old ones, otherwise only some of the old statements could
		// be found after the power fails, and they would be copied over newer
		// pages.
		file.flush()
		fsync(file, path)!
		salt = rand.u32()
		tail = wal_header_size
		checksum = salt
		log.seek(0, .start)!
		log.write(wal_header(salt, pager.page_size, wal_state_committed, tail, checksum))!
		log.flush()
		fsync(log, log_path)!

		// A new file must also be synced in its directory, otherwise it may not
		// exist after a crash.
		if is_new {
			fsync_dir(os.dir(os.real_path(log_path)))!
		}
	}

	wal_corrupt_fault(mut log, wal_header(salt, pager.page_size, wal_state_committed,
		tail, checksum), salt)!

	// If the process stops after this point, the next statement has to look for
	// this statement in the log.
	log.seek(wal_state_offset, .start)!
	log.write([wal_state_committed])!

	log.seek(tail, .start)!
	for page_number in page_numbers {
		crash_point()
		frame, frame_checksum := wal_frame(wal_frame_page, page_number, pages[page_number],
			checksum)
		log.write(frame)!
		checksum = frame_checksum
	}

	crash_point()
	fault_point('wal_write')!
	commit_frame, commit_checksum := wal_frame(wal_frame_commit, pager.total_pages, header_bytes,
		checksum)
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

	// This is the point where the statement is committed, so the statement must
	// not fail after this. If the log can't be copied into the database file,
	// it's left as it is, and it's copied by wal_recover before the file is
	// read again (by the next statement or connection).
	crash_point()
	wal_checkpoint(mut file, path, pager.page_size, pages, header_bytes, pager.total_pages) or {
		return
	}

	// This is a single write so that the state and the tail always agree. It
	// doesn't need to reach the disk because everything in the log is copied
	// after the power fails, see wal_has_statements.
	log.seek(0, .start)!
	log.write(wal_header(salt, pager.page_size, wal_state_checkpointed, tail + size, commit_checksum))!
}

// wal_tail returns the salt of the log, where the next statement goes, and the
// checksum before it. The position is zero if a new log needs to be started.
fn wal_tail(mut log os.File, page_size int) (u32, int, u32) {
	mut header := []u8{len: wal_header_size}
	read := log.read(mut header) or { 0 }
	if read != wal_header_size || !wal_header_is_valid(header)
		|| binary.big_endian_u16_at(header, wal_magic.len) != wal_version
		|| int(binary.big_endian_u32_at(header, 12)) != page_size {
		return 0, 0, 0
	}

	return binary.big_endian_u32_at(header, 16), int(binary.big_endian_u32_at(header, wal_tail_offset)), binary.big_endian_u32_at(header,
		wal_tail_checksum_offset)
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

	log.seek(0, .start)!
	log.write(corrupt)!
	log.flush()

	return fault_error(name)
}

// wal_checkpoint copies the pages and header of committed statements into the
// database file. The file isn't synced.
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
}

// wal_read_header returns the header of the log, or none if it's too short to
// have one.
fn wal_read_header(path string) ?[]u8 {
	log_path := wal_path(path)
	if !os.exists(log_path) {
		return none
	}

	mut log := os.open(log_path) or { return none }
	defer {
		log.close()
	}

	mut header := []u8{len: wal_header_size}
	read := log.read(mut header) or { return none }

	return if read == wal_header_size { header } else { none }
}

// wal_needs_recovery returns true if a process stopped before a statement in
// the log was copied into the database file. It doesn't need a lock, but
// wal_recover does.
fn wal_needs_recovery(path string) bool {
	header := wal_read_header(path) or { return false }

	return header[wal_state_offset] != wal_state_checkpointed
}

// wal_has_statements returns true if the log contains statements that may not
// be on the disk in the database file. They are all in the database file unless
// the power failed, which can only have happened if this is the first connection
// to the file, see CatalogConnection.recover_log.
fn wal_has_statements(path string) bool {
	header := wal_read_header(path) or { return false }

	return header[wal_state_offset] != wal_state_checkpointed
		|| int(binary.big_endian_u32_at(header, wal_tail_offset)) > wal_header_size
}

// wal_recover copies the log into the database file if a process stopped before
// doing it. It must only be called with the database file locked exclusively.
fn wal_recover(mut file os.File, path string) ! {
	if wal_needs_recovery(path) {
		wal_replay(mut file, path)!
	}
}

// wal_replay copies the committed statements in the log into the database file,
// syncs it, and then empties the log. A statement that wasn't committed (it isn't
// followed by a valid commit frame) is ignored, because the database file wasn't
// changed. Copying a statement that's already in the database file doesn't change
// it.
//
// It must only be called with the database file locked exclusively.
fn wal_replay(mut file os.File, path string) ! {
	fault_point('recover')!

	log_path := wal_path(path)
	data := os.read_bytes(log_path) or { return sqlstate_58030('unable to read ${log_path}: ${err}') }

	if data.len >= wal_header_size && data[..wal_magic.len] == wal_magic {
		version := binary.big_endian_u16_at(data, wal_magic.len)
		if version > wal_version {
			return sqlstate_0a000('${log_path} uses version ${version} of the write-ahead log, but this version of vsql only supports up to ${wal_version}')
		}
	}

	if commit := wal_read(data) {
		wal_checkpoint(mut file, path, commit.page_size, commit.pages, commit.header_bytes,
			commit.total_pages)!
		fsync(file, path)!
	}

	// The "b" is needed on Windows, otherwise the file is opened in text mode.
	mut log := os.open_file(log_path, 'rb+') or {
		return sqlstate_58030('unable to open ${log_path}: ${err}')
	}
	defer {
		log.close()
	}

	// A tail of zero means the next statement starts a new log. This has to be
	// written first, so that the log isn't added to if the process stops here.
	log.seek(wal_tail_offset, .start)!
	log.write([]u8{len: 8})!
	log.seek(wal_state_offset, .start)!
	log.write([wal_state_checkpointed])!
}

struct WalCommit {
	page_size    int
	pages        map[int][]u8
	header_bytes []u8
	total_pages  int
}

// wal_read returns the combined changes of the committed statements in the log,
// or none if there aren't any. Reading stops at the first frame that isn't valid,
// which is where a process stopped while writing the log.
fn wal_read(data []u8) ?WalCommit {
	if data.len < wal_header_size || !wal_header_is_valid(data[..wal_header_size]) {
		return none
	}

	page_size := int(binary.big_endian_u32_at(data, 12))
	salt := binary.big_endian_u32_at(data, 16)

	mut pages := map[int][]u8{}
	mut pending := map[int][]u8{}
	mut header_bytes := []u8{}
	mut total_pages := 0
	mut committed := false
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
				pending[number] = frame_data
			}
			wal_frame_commit {
				for page_number, page in pending {
					pages[page_number] = page
				}
				pending = map[int][]u8{}
				header_bytes = frame_data.clone()
				total_pages = number
				committed = true
			}
			else {
				break
			}
		}
	}

	if !committed {
		return none
	}

	return WalCommit{page_size, pages, header_bytes, total_pages}
}

fn wal_header(salt u32, page_size int, state u8, tail int, tail_checksum u32) []u8 {
	mut header := []u8{len: wal_header_size}
	for i, b in wal_magic {
		header[i] = b
	}
	binary.big_endian_put_u16_at(mut header, wal_version, wal_magic.len)
	binary.big_endian_put_u32_at(mut header, u32(page_size), 12)
	binary.big_endian_put_u32_at(mut header, salt, 16)
	binary.big_endian_put_u32_at(mut header, crc32.sum(header[..wal_header_size - 4]),
		wal_header_size - 4)

	header[wal_state_offset] = state
	binary.big_endian_put_u32_at(mut header, u32(tail), wal_tail_offset)
	binary.big_endian_put_u32_at(mut header, tail_checksum, wal_tail_checksum_offset)

	return header
}

// wal_header_is_valid checks the magic number and the checksum of a log header.
fn wal_header_is_valid(data []u8) bool {
	if data[..wal_magic.len] != wal_magic {
		return false
	}

	mut header := data.clone()
	header[wal_state_offset] = 0
	for i in wal_tail_offset .. wal_header_size - 4 {
		header[i] = 0
	}

	return crc32.sum(header[..wal_header_size - 4]) == binary.big_endian_u32_at(header,
		wal_header_size - 4)
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

// wal_checksum is the CRC-32 of the previous checksum, the frame header and the
// data, one after the other. It's calculated in parts, so that the data isn't
// copied.
fn wal_checksum(previous_checksum u32, frame_header []u8, data []u8) u32 {
	checksum := crc32.sum(binary.big_endian_get_u32(previous_checksum))

	return wal_crc32.update(wal_crc32.update(checksum, frame_header), data)
}

const wal_crc32 = crc32.new(crc32.ieee)

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
		// _exit doesn't run the atexit handlers, which is where a coverage build
		// writes what it covered. So a coverage build exits normally instead (see
		// test_crash_point).
		$if coverage ? {
			exit(1)
		} $else {
			C._exit(1)
		}
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
