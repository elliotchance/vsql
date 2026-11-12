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

fn (mut c StatementCache) find(sql_stmt string) ?ParsedStmt {
	i := c.slot_of[sql_stmt] or { return none }
	c.slots[i].used = true

	return c.slots[i].parsed
}

fn (mut c StatementCache) add(sql_stmt string, parsed ParsedStmt) {
	if sql_stmt.len > statement_cache_max_length {
		return
	}

	slot := StatementSlot{
		sql_stmt: sql_stmt
		parsed:   parsed
	}
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
	c.slot_of[sql_stmt] = c.hand
	c.slots[c.hand] = slot
	c.hand = (c.hand + 1) % c.slots.len
}
