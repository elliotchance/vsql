// statement_cache.v keeps the statements that a connection has parsed, by
// their text, so that a statement that runs again isn't parsed again.

module vsql

// statement_cache_size is the most statements that a connection keeps parsed.
const statement_cache_size = 256

// statement_cache_max_length is the longest text (in bytes) of a statement
// that's kept parsed. A longer statement is unlikely to be repeated, and would
// take up more memory.
const statement_cache_max_length = 4096

// A ParsedStmt is what parse_sql finds in the text of a statement. It only
// depends on the text (not the schema, the connection or any values), so it
// never needs to be invalidated. The plan, which depends on the schema, is
// still made each time the statement runs.
//
// The statement is shared by every PreparedStmt made from the same text. That's
// safe because a statement isn't changed after it's parsed (a PreparedStmt can
// already run many times).
struct ParsedStmt {
	stmt               Stmt
	explain            bool
	writes             bool
	dynamic_parameters int
	features           []string
}

// A StatementSlot is one entry of a StatementCache. used is set each time it's
// found, see StatementCache.add.
struct StatementSlot {
	sql_stmt string
	parsed   ParsedStmt
	// arena is the arena the statement was parsed in, if any (see
	// cache_arena_begin), which is freed when the slot is replaced.
	arena voidptr
mut:
	used bool
}

// A StatementCache holds up to statement_cache_size ParsedStmts, by their text.
// When it's full, the slot to replace is chosen with the CLOCK algorithm: the
// hand skips (and clears) slots that have been used since it last passed them.
// So statements that keep running stay cached, even when many statements (such
// as ones with different literal values) only run once.
struct StatementCache {
mut:
	slot_of map[string]int
	slots   []StatementSlot
	hand    int
}

// find and add copy the statement in and out of the cache, so that the cache
// and the caller never free the same statement. That works around
// https://github.com/vlang/v/issues/32949 (-autofree), where a copy of the
// element of an array (or the parameter that's stored in one) is freed while
// the array still holds it.
@[manualfree]
fn (mut c StatementCache) find(sql_stmt string) ?ParsedStmt {
	i := c.slot_of[sql_stmt] or { return none }
	c.slots[i].used = true

	return own_copy(&c.slots[i].parsed)
}

@[manualfree]
fn (mut c StatementCache) add(sql_stmt string, parsed &ParsedStmt, arena voidptr) {
	if sql_stmt.len > statement_cache_max_length {
		return
	}

	// The copies are made in the statement's own arena, if it has one, so
	// they're freed with it (see cache_arena_begin).
	arena_resume(arena)
	slot := StatementSlot{
		sql_stmt: own_string(sql_stmt)
		parsed:   own_copy(parsed)
		arena:    arena
	}
	cache_arena_end(arena)
	if c.slots.len < statement_cache_size {
		c.slot_of[sql_stmt] = c.slots.len
		c.slots << slot
		return
	}

	for c.slots[c.hand].used {
		c.slots[c.hand].used = false
		c.hand = (c.hand + 1) % c.slots.len
	}
	c.slot_of.delete(c.slots[c.hand].sql_stmt)
	arena_free_handle(c.slots[c.hand].arena)
	c.slot_of[sql_stmt] = c.hand
	// The slot is moved, since -autofree would clone it.
	unsafe { vmemcpy(&c.slots[c.hand], &slot, int(sizeof(StatementSlot))) }
	c.hand = (c.hand + 1) % c.slots.len
}

// free_arenas empties the cache and frees the arena of each statement in it,
// when the connection is closed. The slots are forgotten rather than freed,
// because what they have is in those arenas.
fn (mut c StatementCache) free_arenas() {
	for slot in c.slots {
		arena_free_handle(slot.arena)
	}
	unsafe {
		c.slots.len = 0
	}
	c.slot_of.clear()
	c.hand = 0
}
