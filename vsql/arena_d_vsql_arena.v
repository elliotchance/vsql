module vsql

import arena
import builtin.closure

// The statement arena (-d vsql_arena) is a prototype: everything that's
// allocated while the outermost statement of a connection runs (parsing,
// planning and executing it) comes from an arena that's released when the
// statement ends, rather than being freed one value at a time. Whatever must
// outlive the statement (the pages the pager keeps, the statement cache, the
// result) is allocated while the arena is paused (see arena_pause), or copied
// out of it after it's popped.
//
// With -d vsql_arena_debug each statement gets a new arena that's freed at the
// end, so its memory goes back to malloc and ASan reports anything that still
// points into it.

// arena_begin starts the arena of a statement, unless one is already running
// (a statement run by another one uses its arena). It's true if it started.
fn (mut c Connection) arena_begin() bool {
	if !isnil(c.arena) || arena.active() {
		return false
	}
	$if vsql_arena_debug ? {
		c.arena = unsafe { v_arena_new(0) }
	} $else {
		if isnil(c.arena_kept) {
			c.arena_kept = unsafe { v_arena_new(0) }
		}
		c.arena = c.arena_kept
	}
	unsafe { v_arena_push(c.arena) }
	return true
}

// arena_pop stops allocating from the statement's arena, so that what it
// returns can be copied out of it before arena_release.
fn (mut c Connection) arena_pop() {
	unsafe { v_arena_pop(c.arena) }
}

// arena_release releases the memory of the statement's arena (it must be
// popped).
fn (mut c Connection) arena_release() {
	for h in c.deferred_arenas {
		unsafe { v_arena_free(h) }
	}
	c.deferred_arenas.clear()
	$if vsql_arena_debug ? {
		unsafe { v_arena_free(c.arena) }
	} $else {
		unsafe { v_arena_reset(c.arena) }
	}
	c.arena = unsafe { nil }
}

// arena_pause pops the arenas that are allocating (if any), so that values
// that must outlive the statement come from the heap until arena_resume. It's
// the arena, or (when a scratch arena is pushed on the statement's, see
// scratch_arena_begin) an ArenaPause with the low bit set.
fn arena_pause() voidptr {
	h := v_arena_current()
	if isnil(h) {
		return h
	}
	unsafe { v_arena_pop(h) }
	if isnil(v_arena_current()) {
		return h
	}
	mut paused := unsafe { &ArenaPause(C.calloc(1, sizeof(ArenaPause))) }
	paused.handles[0] = h
	paused.len = 1
	for paused.len < paused.handles.len {
		next := v_arena_current()
		if isnil(next) {
			break
		}
		unsafe { v_arena_pop(next) }
		paused.handles[paused.len] = next
		paused.len++
	}
	return voidptr(uint(paused) | 1)
}

// arena_resume pushes the arenas that arena_pause popped again.
fn arena_resume(h voidptr) {
	if isnil(h) {
		return
	}
	if uint(h) & 1 == 0 {
		unsafe { v_arena_push(h) }
		return
	}
	paused := unsafe { &ArenaPause(uint(h) & ~uint(1)) }
	for i := paused.len - 1; i >= 0; i-- {
		unsafe { v_arena_push(paused.handles[i]) }
	}
	unsafe { C.free(paused) }
}

// ArenaPause is the arenas that arena_pause popped, the top one first.
struct ArenaPause {
mut:
	handles [4]voidptr
	len     int
}

// cache_arena_begin starts the arena that a statement is parsed in when it'll
// be kept by the statement cache (only while a statement arena is running), so
// that the parsed statement lives as long as it's cached, without copying it.
// It's nil if there isn't one.
fn cache_arena_begin(statement_arena voidptr) voidptr {
	if isnil(statement_arena) {
		return unsafe { nil }
	}
	h := unsafe { v_arena_new(4096) }
	unsafe { v_arena_push(h) }
	return h
}

// cache_arena_end stops allocating from the cache arena (see
// cache_arena_begin).
fn cache_arena_end(h voidptr) {
	if !isnil(h) {
		unsafe { v_arena_pop(h) }
	}
}

// arena_free_handle frees an arena that isn't pushed, such as the one of a
// statement that's removed from the statement cache.
fn arena_free_handle(h voidptr) {
	if !isnil(h) {
		unsafe { v_arena_free(h) }
	}
}

// detached is a copy of r that doesn't point into the statement's arena, so it
// can be returned after the arena is released (the arena must be popped). A
// plain copy isn't enough: the strings, times and numbers of a Value are boxed
// behind pointers that a clone shares, RowData.clone shares its keys, and the
// columns have the names of the parsed statement.
fn (r Result) detached() Result {
	mut columns := []Column{cap: r.columns.len}
	for i in 0 .. r.columns.len {
		columns << r.columns[i].detached()
	}
	mut rows := []Row{cap: r.rows.len}
	for i in 0 .. r.rows.len {
		rows << r.rows[i].detached()
	}
	return Result{
		columns:       columns
		rows:          rows
		elapsed_parse: r.elapsed_parse
		elapsed_exec:  r.elapsed_exec
		msg:           r.msg.clone()
		idx:           r.idx
	}
}

// detached is a copy of c with its own names (see Result.detached). The
// default, identity and generation clause of a table's column belong to the
// schema, which isn't in the arena.
fn (c Column) detached() Column {
	return Column{
		name:          c.name.detached()
		typ:           c.typ
		not_null:      c.not_null
		default_value: c.default_value
		default_text:  c.default_text.clone()
		identity:      c.identity
		generated:     c.generated
		unnamed:       c.unnamed
	}
}

// detached is a copy of i with its own strings (see Result.detached).
fn (i Identifier) detached() Identifier {
	return Identifier{
		catalog_name:    i.catalog_name.clone()
		schema_name:     i.schema_name.clone()
		entity_name:     i.entity_name.clone()
		sub_entity_name: i.sub_entity_name.clone()
		custom_id:       i.custom_id.clone()
		custom_typ:      i.custom_typ
	}
}

// detached is a copy of r with its own keys and values (see Result.detached).
fn (r Row) detached() Row {
	mut keys := []string{cap: r.data.keys.len}
	for i in 0 .. r.data.keys.len {
		keys << r.data.keys[i].clone()
	}
	mut values := []Value{cap: r.data.values.len}
	for i in 0 .. r.data.values.len {
		values << r.data.values[i].detached()
	}
	return Row{
		id:   r.id.clone()
		tid:  r.tid
		data: RowData{
			keys:   keys
			values: values
		}
	}
}

// detached is a copy of v with its own box (see Result.detached). A large value
// is read now, because the pages it's read from may be in the arena. If it
// can't be read, it's left to be read (and fail) later, like it would be
// without the arena.
fn (v Value) detached() Value {
	if v.is_large {
		mut lv := v.large_value()
		s := lv.load() or { return v }
		return Value{
			typ: v.typ
			v:   InternalValue{
				string_value: box_string(s)
			}
		}
	}
	mut iv := v.v
	unsafe {
		match v.typ.typ {
			.is_varchar, .is_character, .is_clob, .is_binary, .is_varbinary, .is_blob {
				if !isnil(iv.string_value) {
					iv.string_value = box_string((&StringBox(iv.string_value)).s)
				}
			}
			.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
			.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
				if !isnil(iv.time_value) {
					iv.time_value = box_time(*(&Time(iv.time_value)))
				}
			}
			.is_decimal, .is_numeric {
				if !isnil(iv.numeric_value) {
					iv.numeric_value = box_numeric(*(&Numeric(iv.numeric_value)))
				}
			}
			.is_decfloat {
				if !isnil(iv.decfloat_value) {
					iv.decfloat_value = box_decfloat(*(&DecFloat(iv.decfloat_value)))
				}
			}
			else {}
		}
	}
	return Value{
		typ:     v.typ
		is_null: v.is_null
		v:       iv
	}
}

// scratch_arena_begin starts a scratch arena while the statement's arena is
// running (it's nil otherwise), such as for reading a virtual table (see
// VirtualTableOperation.execute). It's released once what it returns is copied
// out of it (see detached_rows), so work that's repeated for each row of a
// query (a virtual table in a correlated subquery) doesn't keep everything it
// allocated until the statement ends. The arenas are reused, one for each
// level of nesting.
//
// A subquery can't have one: the closures it makes are released when the
// statement ends (see Connection.run_frame), after its arena.
fn (mut c Connection) scratch_arena_begin() voidptr {
	if isnil(c.arena) || !arena.active() {
		return unsafe { nil }
	}
	mut h := unsafe { nil }
	$if vsql_arena_debug ? {
		h = unsafe { v_arena_new(0) }
	} $else {
		if c.scratch_depth >= c.scratch_arenas.len {
			ph := arena_pause()
			c.scratch_arenas << voidptr(0)
			arena_resume(ph)
		}
		if isnil(c.scratch_arenas[c.scratch_depth]) {
			c.scratch_arenas[c.scratch_depth] = unsafe { v_arena_new(0) }
		}
		h = c.scratch_arenas[c.scratch_depth]
	}
	c.scratch_depth++
	ph := arena_pause()
	c.scratch_closures << tracked_closures(&c.lifetime)
	arena_resume(ph)
	unsafe { v_arena_push(h) }
	return h
}

// scratch_arena_pop stops allocating from a scratch arena, so that what it
// returns can be copied out of it (see scratch_arena_begin).
fn (mut c Connection) scratch_arena_pop(h voidptr) {
	if !isnil(h) {
		unsafe { v_arena_pop(h) }
	}
}

// scratch_arena_release releases the memory of a scratch arena (it must be
// popped).
fn (mut c Connection) scratch_arena_release(h voidptr) {
	if isnil(h) {
		return
	}
	c.scratch_depth--
	ph := arena_pause()
	closures := c.scratch_closures.pop()
	arena_resume(ph)

	// The closures made while it was pushed (by a virtual table that compiles
	// expressions) are released when the statement ends (see
	// Connection.run_frame), so the arena is kept until then.
	if tracked_closures(&c.lifetime) > closures {
		ah := arena_pause()
		c.deferred_arenas << h
		arena_resume(ah)
		$if !vsql_arena_debug ? {
			c.scratch_arenas[c.scratch_depth] = unsafe { nil }
		}
		return
	}
	$if vsql_arena_debug ? {
		unsafe { v_arena_free(h) }
	} $else {
		unsafe { v_arena_reset(h) }
	}
}

// ClosureLifetimeStateView is the start of builtin.closure's
// ClosureLifetimeState, which is private, so that tracked_closures can count
// its records. It must be kept in step with V (it's only for the prototype).
struct ClosureLifetimeStateView {
	owner_thread     u64
	active           bool
	disposed         bool
	suspended        int
	frame_start      int
	frame_gen        u64
	generation       u64
	frame_generation u64
	records          []u8
}

// tracked_closures is the number of closures that lifetime will release.
fn tracked_closures(lifetime &closure.Lifetime) int {
	state := unsafe { *(&voidptr(lifetime)) }
	if isnil(state) {
		return 0
	}
	return unsafe { (&ClosureLifetimeStateView(state)).records.len }
}

// detached_rows is a copy of rows that doesn't point into the arena h (see
// Row.detached), or rows when there's no arena.
fn detached_rows(h voidptr, rows []Row) []Row {
	if isnil(h) {
		return rows
	}
	mut copies := []Row{cap: rows.len}
	for i in 0 .. rows.len {
		copies << rows[i].detached()
	}
	return copies
}

// chunk_arena_begin pushes an arena for writing one chunk of a large value
// (see Storage.write_large_value), when a statement arena is running.
// chunk_arena_end pops it, and releases it when ok (an error may point into
// it, so it's then only released by the next chunk that's written).
fn (mut f Storage) chunk_arena_begin() voidptr {
	if !arena.active() {
		return unsafe { nil }
	}
	$if vsql_arena_debug ? {
		h := unsafe { v_arena_new(0) }
		unsafe { v_arena_push(h) }
		return h
	} $else {
		if isnil(f.chunk_arena) {
			ph := arena_pause()
			f.chunk_arena = unsafe { v_arena_new(0) }
			arena_resume(ph)
		}
		unsafe { v_arena_push(f.chunk_arena) }
		return f.chunk_arena
	}
}

fn (mut f Storage) chunk_arena_end(h voidptr, ok bool) {
	if isnil(h) {
		return
	}
	unsafe { v_arena_pop(h) }
	if !ok {
		return
	}
	$if vsql_arena_debug ? {
		unsafe { v_arena_free(h) }
	} $else {
		unsafe { v_arena_reset(h) }
	}
}

// chunk_arena_free frees the arena of chunk_arena_begin, when the storage is
// closed.
fn (mut f Storage) chunk_arena_free() {
	if !isnil(f.chunk_arena) {
		unsafe { v_arena_free(f.chunk_arena) }
		f.chunk_arena = unsafe { nil }
	}
}

// in_current_arena is true if p is memory of the arena that's being allocated
// from, so a copy of it would live exactly as long as it does (see
// own_string).
fn in_current_arena(p voidptr) bool {
	h := unsafe { v_arena_current() }
	return !isnil(h) && unsafe { v_arena_owns(h, p) }
}

// arena_close frees every arena that the connection keeps between statements,
// when it's closed (unless it's closed by a statement that's running).
fn (mut c Connection) arena_close() {
	if !isnil(c.arena) {
		return
	}
	arena_free_handle(c.arena_kept)
	c.arena_kept = unsafe { nil }
	for h in c.scratch_arenas {
		arena_free_handle(h)
	}
	c.scratch_arenas.clear()
	for h in c.deferred_arenas {
		arena_free_handle(h)
	}
	c.deferred_arenas.clear()
	c.statement_cache.free_arenas()
	for _, mut catalog in c.catalogs {
		catalog.storage.chunk_arena_free()
	}
}
