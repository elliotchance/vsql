module vsql

// Without -d vsql_arena there's no statement arena (see arena_d_vsql_arena.v).

fn (mut c Connection) arena_begin() bool {
	return false
}

fn (mut c Connection) arena_pop() {
}

fn (mut c Connection) arena_release() {
}

fn arena_pause() voidptr {
	return unsafe { nil }
}

fn arena_resume(h voidptr) {
}

fn cache_arena_begin(statement_arena voidptr) voidptr {
	return unsafe { nil }
}

fn cache_arena_end(h voidptr) {
}

fn arena_free_handle(h voidptr) {
}

// detached is r: without the arena, nothing points into one.
fn (r Result) detached() Result {
	return r
}

fn (mut c Connection) scratch_arena_begin() voidptr {
	return unsafe { nil }
}

fn (mut c Connection) scratch_arena_pop(h voidptr) {
}

fn (mut c Connection) scratch_arena_release(h voidptr) {
}

fn (mut f Storage) chunk_arena_begin() voidptr {
	return unsafe { nil }
}

fn (mut f Storage) chunk_arena_end(h voidptr, ok bool) {
}

fn (mut f Storage) chunk_arena_free() {
}

// detached_rows is rows: without the arena, nothing points into one.
fn detached_rows(h voidptr, rows []Row) []Row {
	return rows
}

fn in_current_arena(p voidptr) bool {
	return false
}

fn (mut c Connection) arena_close() {
}
