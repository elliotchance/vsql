module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.5, <savepoint statement>
//
// Establish a savepoint.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.41.2, Savepoints
//
// There's only one savepoint level, because there are no SQL-invoked routines
// (T321) or atomic blocks. There's no maximum number of savepoints, so 3B002
// (too many) is never raised.
//
// A statement on its own is its own SQL-transaction, so a savepoint outside of
// one ends straight away.

struct SavepointStatement {
	name string
}

// Savepoint is a point in the current SQL-transaction that it can be rolled back
// to, with the state of each catalog at that point.
//
// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, General Rules, 26
struct Savepoint {
	name string
mut:
	catalogs map[string]SavepointState
}

// SavepointState is where a catalog was when the savepoint was established.
struct SavepointState {
	undo_length     int
	deferred_checks map[string]string
}

// savepoint_state must be called with the transaction started, and starts the
// undo log.
fn (mut f Storage) savepoint_state() SavepointState {
	f.undo.recording = true

	return SavepointState{
		undo_length:     f.undo.entries.len
		deferred_checks: f.deferred_checks.clone()
	}
}

fn (stmt SavepointStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if conn.in_transaction() {
		// A savepoint that is destroyed doesn't destroy the ones after it.
		//
		// ISO/IEC 9075-2:2016(E), 17.5, <savepoint statement>, General Rules, 1 and 2
		conn.savepoints = conn.savepoints.filter(it.name != stmt.name)

		// ISO/IEC 9075-2:2016(E), 17.5, <savepoint statement>, General Rules, 4
		mut savepoint := Savepoint{
			name: stmt.name
		}
		for name, mut catalog in conn.catalogs {
			savepoint.catalogs[name] = catalog.storage.savepoint_state()
		}
		conn.savepoints << savepoint
	}

	return new_result_msg('SAVEPOINT', elapsed_parse, t.elapsed())
}

fn (stmt SavepointStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SAVEPOINT')
}

// savepoint_index is the position in savepoints of a savepoint by its name.
//
// ISO/IEC 9075-2:2016(E), 17.6, <release savepoint statement>, General Rules, 2
// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 3.b
//
// That's only needed for 17.6 and 17.8, so it's here beside what they share.
fn (conn Connection) savepoint_index(name string) !int {
	for i, savepoint in conn.savepoints {
		if savepoint.name == name {
			return i
		}
	}

	return sqlstate_3b001(name)
}

// rollback_to_savepoint cancels the changes after a savepoint, which stays, and
// destroys the ones after it. A cursor that isn't holdable is closed. A holdable
// cursor stays open, which is implementation-defined, and it's a copy of its rows
// so it isn't changed. Nothing changes for other connections, because none of
// these changes have been committed, so they don't need to reload the schema.
//
// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 3, 3.d, 3.e, 3.g and 3.h
fn (mut conn Connection) rollback_to_savepoint(name string) ! {
	index := conn.savepoint_index(name)!

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	savepoint := conn.savepoints[index]
	for catalog_name, mut catalog in conn.catalogs {
		catalog.rollback_to(savepoint.catalogs[catalog_name] or { SavepointState{} })!
	}
	conn.savepoints.trim(index + 1)
	for _, mut cursor in conn.cursors {
		if !cursor.hold {
			cursor.close()
		}
	}
}

fn (mut catalog CatalogConnection) rollback_to(state SavepointState) ! {
	// A table (T), schema (S) or index (N) that's changed means the schema must be
	// loaded again.
	schema_changed := catalog.storage.undo.entries[state.undo_length..].any(it.obj.key[0] in [
		`T`,
		`S`,
		`N`,
	])

	catalog.storage.isolation_start()!
	catalog.storage.keep_undo_log()
	catalog.storage.btree.undo_to(state.undo_length)!
	catalog.storage.isolation_end()!
	catalog.storage.deferred_checks = state.deferred_checks.clone()

	if schema_changed {
		catalog.storage.load_schema(catalog.catalog_name)!
	}
}
