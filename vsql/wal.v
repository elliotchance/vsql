// wal.v implements the write-ahead log, which makes each statement that changes
// a database file atomic and durable. See "Write-Ahead Log" in the file format
// docs.

module vsql

import encoding.binary
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
//
// Starting again syncs the database file and the new log, and then each page
// that a statement in an explicit transaction changes has to be synced in the
// new log before that statement can skip syncing (see WalLog.can_skip_sync).
// So a bigger log is synced less often, at the cost of the space it takes up
// (the log isn't made smaller when it starts again).
const wal_max_size = 16 * 1024 * 1024

const wal_state_committed = u8(0)

const wal_state_checkpointed = u8(1)

const wal_frame_page = u8(1)

const wal_frame_commit = u8(2)

fn wal_path(path string) string {
	return '${path}.wal'
}

// WalLog is the log of a database file, which stays open between statements
// (like Storage.file) once it exists.
struct WalLog {
	path string
	// full_fsync is ConnectionOptions.full_fsync.
	full_fsync bool
mut:
	file     os.File
	identity FileIdentity
	// The rest is what this connection knows about the frames in the log, which
	// decides whether a statement in an explicit transaction can skip syncing
	// it, see can_skip_sync. It's for the log with salt, while its tail is at
	// least tail (another connection starts a new log with a new salt, and a
	// smaller tail), and it's forgotten when known is false.
	known bool
	salt  u32
	tail  int
	// synced_pages are the pages that this connection wrote frames for and then
	// synced, and synced_total_pages is the number of pages at the last sync.
	// unsynced_pages are the pages that it wrote since, which are synced along
	// with the next statement that syncs the log.
	synced_pages       map[int]bool
	unsynced_pages     map[int]bool
	synced_total_pages int
}

// sync must be called each time the database file is locked, because another
// connection may have created the log, or something else may have replaced or
// deleted it, while it wasn't locked. The log is opened again if it isn't the
// file at path. It's unbuffered, so nothing read before the lock is used.
fn (mut l WalLog) sync() {
	identity := path_file_identity(l.path) or {
		l.file.close()
		return
	}
	if l.file.is_opened && identity == l.identity {
		return
	}

	l.file.close()
	l.known = false
	// The "b" is needed on Windows, otherwise the file is opened in text mode.
	l.file = os.open_file(l.path, 'rb+') or { return }
	l.opened()
}

// create starts a new log, which must not exist yet. It's opened for reading
// too, because it stays open for the statements after this one.
fn (mut l WalLog) create() ! {
	l.known = false
	l.file = os.open_file(l.path, 'wb+')!
	l.opened()
}

// A WalPosition is where the end of the log is, see WalLog.position.
struct WalPosition {
	salt u32
	tail int
}

// position returns where the end of the log is. It's none when there's no log,
// or it isn't valid (so the next statement starts a new one).
fn (mut l WalLog) position(page_size int) ?WalPosition {
	if !l.file.is_opened {
		return none
	}
	salt, tail, _ := wal_tail(mut l.file, page_size)
	if tail == 0 {
		return none
	}

	return WalPosition{salt, tail}
}

// can_skip_sync returns true if the statement can be committed without syncing
// the log, which is only allowed for a statement in an explicit transaction
// (see wal_prepare). Its pages are copied into the database file straight
// away, and some of them may reach the disk before the power fails while the
// log doesn't. That's safe if replaying the log puts back every page that
// changed since the database file was last synced (wal_replay copies the
// statements up to the last one that was synced, and truncates the file to
// its number of pages). So every page must already have a frame that has been
// synced in this log, or be past the number of pages at the last sync. (The
// file never gets smaller, so a page past that can only be a new one.)
fn (l WalLog) can_skip_sync(prepared WalPrepared) bool {
	if !l.knows(prepared) {
		return false
	}

	for page_number, _ in prepared.pages {
		if page_number < l.synced_total_pages && page_number !in l.synced_pages {
			return false
		}
	}

	return true
}

// knows returns true if what this connection knows about the log is still for
// the log that the statement was added to.
fn (l WalLog) knows(prepared WalPrepared) bool {
	return l.known && !prepared.new_log && prepared.salt == l.salt && prepared.tail >= l.tail
}

// finished records a statement that wal_finish added to the log.
fn (mut l WalLog) finished(prepared WalPrepared) {
	if !l.knows(prepared) {
		l.known = false
		l.synced_pages = map[int]bool{}
		l.unsynced_pages = map[int]bool{}
		l.synced_total_pages = 0
	}

	for page_number, _ in prepared.pages {
		l.unsynced_pages[page_number] = true
	}
	if prepared.sync {
		// Syncing the log also syncs the frames before this statement.
		for page_number, _ in l.unsynced_pages {
			l.synced_pages[page_number] = true
		}
		l.unsynced_pages = map[int]bool{}
		l.synced_total_pages = prepared.total_pages
		l.known = true
	}

	l.salt = prepared.salt
	l.tail = prepared.tail + prepared.size
}

fn (mut l WalLog) opened() {
	l.file.set_unbuffered()
	l.identity = open_file_identity(l.file)
}

// WalPrepared is a statement that has been added to the log, except for the
// commit frame, see wal_prepare.
struct WalPrepared {
mut:
	// log is a copy of WalLog.file, which stays open.
	log          os.File
	log_path     string
	salt         u32
	tail         int
	size         int
	checksum     u32
	page_size    int
	pages        map[int][]u8
	header_bytes []u8
	total_pages  int
	full_fsync   bool
	// new_log is true if the statement started a new log.
	new_log bool
	// sync is false if the log doesn't need to be synced, see can_skip_sync.
	sync bool = true
}

// wal_prepare and wal_finish make the changes of a statement permanent. The
// changed pages and the header are added to the log, which is synced to the
// disk. Then they are copied into the database file, without syncing it,
// because the log still has them. If the process stops or the power fails at
// any point, the database file can be fixed by wal_recover or wal_replay.
//
// in_transaction is true for a statement in an explicit transaction, which
// doesn't need to survive the power failing, because the transaction would be
// rolled back anyway. The log isn't synced for it if that's safe, see
// WalLog.can_skip_sync. The COMMIT syncs it.
//
// They must only be called with the database file locked exclusively, and
// after wal_recover.
//
// wal_prepare is the first half. It adds the changed pages of a
// statement to the log, which is everything that's likely to fail, but not the
// commit frame, so the statement isn't committed yet. That lets a COMMIT that
// changes several catalogs (each with its own log) find out that one of them
// can't be written before any of them is committed, see commit_catalogs.
//
// It must be followed by wal_finish, or the WalPrepared can be dropped to give
// up. Frames without a commit frame are ignored by wal_read.
fn wal_prepare(mut file os.File, path string, mut wal WalLog, header Header, pager &FilePager, in_transaction bool) !WalPrepared {
	mut page_numbers := pager.dirty.keys().filter(it < pager.total_pages)
	page_numbers.sort()

	mut prepared := WalPrepared{
		log_path:     wal.path
		page_size:    pager.page_size
		header_bytes: header.bytes()
		total_pages:  pager.total_pages
		full_fsync:   wal.full_fsync
	}

	prepared.size = wal_frame_header_size + prepared.header_bytes.len
	for page_number in page_numbers {
		prepared.pages[page_number] = pager.dirty[page_number]
		prepared.size += wal_frame_header_size + prepared.pages[page_number].len
	}

	log_path := prepared.log_path
	is_new := !wal.file.is_opened
	// A log is reused because replacing it takes longer. Frames left over from
	// the previous log are never valid, because each log has a new salt.
	if is_new {
		wal.create() or { return sqlstate_58030('unable to create ${log_path}: ${err}') }
	}
	prepared.log = wal.file

	wal_write_pages(mut file, path, is_new, page_numbers, mut prepared)!
	prepared.sync = !in_transaction || !wal.can_skip_sync(prepared)

	return prepared
}

// wal_write_pages writes the page frames for wal_prepare.
fn wal_write_pages(mut file os.File, path string, is_new bool, page_numbers []int, mut prepared WalPrepared) ! {
	// The copy is the same open file.
	mut log := prepared.log
	log_path := prepared.log_path
	mut salt, mut tail, mut checksum := wal_tail(mut log, prepared.page_size)
	if tail == 0 || tail + prepared.size > wal_max_size {
		// The statements in the log are about to be lost, so the database file
		// must have them. The new header has to be on the disk before its frames
		// replace the old ones, otherwise only some of the old statements could
		// be found after the power fails, and they would be copied over newer
		// pages.
		file.flush()
		fsync(file, path, prepared.full_fsync)!
		salt = rand.u32()
		tail = wal_header_size
		checksum = salt
		prepared.new_log = true
		log.seek(0, .start)!
		log.write(wal_header(salt, prepared.page_size, wal_state_committed, tail, checksum))!
		log.flush()
		fsync(log, log_path, prepared.full_fsync)!

		// A new file must also be synced in its directory, otherwise it may not
		// exist after a crash.
		if is_new {
			fsync_dir(os.dir(os.real_path(log_path)))!
		}
	}

	wal_corrupt_fault(mut log, wal_header(salt, prepared.page_size, wal_state_committed,
		tail, checksum), salt)!

	// If the process stops after this point, the next statement has to look for
	// this statement in the log.
	log.seek(wal_state_offset, .start)!
	log.write([wal_state_committed])!

	log.seek(tail, .start)!
	for page_number in page_numbers {
		crash_point()
		frame, frame_checksum := wal_frame(wal_frame_page, page_number, prepared.pages[page_number],
			checksum)
		log.write(frame)!
		checksum = frame_checksum
	}

	crash_point()
	fault_point('wal_write')!

	prepared.salt = salt
	prepared.tail = tail
	prepared.checksum = checksum
}

// wal_finish is the second half, see wal_prepare. It adds the commit frame, which
// commits the statement once it's synced (unless it doesn't need to be, see
// WalLog.can_skip_sync), and then copies the statement into the database file.
// The log stays open.
fn wal_finish(mut file os.File, path string, mut prepared WalPrepared) ! {
	// The copy is the same open file.
	mut log := prepared.log

	commit_frame, commit_checksum := wal_frame(wal_frame_commit, prepared.total_pages,
		prepared.header_bytes, prepared.checksum)
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
	if prepared.sync {
		fsync(log, prepared.log_path, prepared.full_fsync)!
	}

	// This is the point where the statement is committed, so the statement must
	// not fail after this. If the log can't be copied into the database file,
	// it's left as it is, and it's copied by wal_recover before the file is
	// read again (by the next statement or connection).
	crash_point()
	wal_checkpoint(mut file, path, prepared.page_size, prepared.pages, prepared.header_bytes,
		prepared.total_pages) or { return }

	// This is a single write so that the state and the tail always agree. It
	// doesn't need to reach the disk because everything in the log is copied
	// after the power fails, see wal_has_statements. If it can't be written,
	// the State stays Committed, so the log is copied again.
	wal_write_header(mut log, wal_header(prepared.salt, prepared.page_size, wal_state_checkpointed,
		prepared.tail + prepared.size, commit_checksum)) or {}
}

// wal_write_header replaces the header of the log.
fn wal_write_header(mut log os.File, header []u8) ! {
	log.seek(0, .start)!
	log.write(header)!
}

// wal_tail returns the salt of the log, where the next statement goes, and the
// checksum before it. The position is zero if a new log needs to be started.
// The header is read from the start of the log, wherever the file is.
fn wal_tail(mut log os.File, page_size int) (u32, int, u32) {
	mut header := []u8{len: wal_header_size}
	read := log.read_from(0, mut header) or { 0 }
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

// wal_read_header returns the header of the log, or none if it doesn't exist or
// is too short to have one.
fn wal_read_header(mut wal WalLog) ?[]u8 {
	mut header := []u8{len: wal_header_size}
	read := wal.file.read_from(0, mut header) or { return none }

	return if read == wal_header_size { header } else { none }
}

// wal_needs_recovery returns true if a process stopped before a statement in
// the log was copied into the database file. It doesn't need a lock, but
// wal_recover does.
fn wal_needs_recovery(mut wal WalLog) bool {
	header := wal_read_header(mut wal) or { return false }

	return header[wal_state_offset] != wal_state_checkpointed
}

// wal_has_statements returns true if the log contains statements that may not
// be on the disk in the database file. They are all in the database file unless
// the power failed, which can only have happened if this is the first connection
// to the file, see CatalogConnection.recover_log.
fn wal_has_statements(mut wal WalLog) bool {
	header := wal_read_header(mut wal) or { return false }

	return header[wal_state_offset] != wal_state_checkpointed
		|| int(binary.big_endian_u32_at(header, wal_tail_offset)) > wal_header_size
}

// wal_recover copies the log into the database file if a process stopped before
// doing it. It must only be called with the database file locked exclusively.
fn wal_recover(mut file os.File, path string, mut wal WalLog) ! {
	if wal_needs_recovery(mut wal) {
		wal_replay(mut file, path, mut wal)!
	}
}

// wal_replay copies the committed statements in the log into the database file,
// syncs it, and then empties the log. A statement that wasn't committed (it isn't
// followed by a valid commit frame) is ignored, because the database file wasn't
// changed. Copying a statement that's already in the database file doesn't change
// it.
//
// It must only be called with the database file locked exclusively.
fn wal_replay(mut file os.File, path string, mut wal WalLog) ! {
	fault_point('recover')!

	log_path := wal.path
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
		fsync(file, path, wal.full_fsync)!
	}

	// The copy is the same open file.
	mut log := wal.file

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
	binary.big_endian_put_u32_at(mut header, crc32_update(0, header[..wal_header_size - 4]),
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

	return crc32_update(0, header[..wal_header_size - 4]) == binary.big_endian_u32_at(header,
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
	checksum := crc32_update(0, binary.big_endian_get_u32(previous_checksum))

	return crc32_update(crc32_update(checksum, frame_header), data)
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
