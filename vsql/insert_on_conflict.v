module vsql

// INSERT ... ON CONFLICT is a vsql extension (V119-02), like PostgreSQL and
// SQLite. A new row that has the same values as a row of the table in a
// PRIMARY KEY, UNIQUE constraint or UNIQUE index (an arbiter) is skipped (DO
// NOTHING), or updates that row instead (DO UPDATE). The standard way to do
// this is MERGE (see MergeStatement).

// OnConflict is the ON CONFLICT of an INSERT. The conflict target is either the
// columns of an arbiter, or the name of a PRIMARY KEY or UNIQUE constraint. It
// has neither for DO NOTHING without one, when every arbiter is used.
struct OnConflict {
	columns         []Identifier
	constraint_name string
	do_update       bool
	set             []SetClause
	condition       ?BooleanValueExpression
}

// A ConflictArbiter is a PRIMARY KEY, UNIQUE constraint or UNIQUE index of a
// table that a new row is checked against.
struct ConflictArbiter {
	name    string
	columns []string
	// index is none for the PRIMARY KEY, whose rows are found by their key.
	index ?Index
	// nulls_distinct means a row with a NULL in any of the columns never
	// conflicts (see check_unique_constraints).
	nulls_distinct bool
	is_constraint  bool
	deferrable     bool
}

// excluded_table is the name of the row that would have been inserted, which
// the DO UPDATE can use, such as "SET x = EXCLUDED.x".
const excluded_table = 'EXCLUDED'

// check returns an error when a <set clause> sets a column more than once, or
// a column doesn't exist.
fn (c OnConflict) check(table Table) ! {
	mut set_columns := map[string]bool{}
	for set in c.set {
		table.column(set.column_name)!
		if set.column_name in set_columns {
			return sqlstate_42601('column ${set.column_name} is set more than once')
		}
		set_columns[set.column_name] = true

		// A generated column, or a GENERATED ALWAYS identity column, can only
		// be set to DEFAULT, like an UPDATE.
		if table.column(set.column_name)!.is_generated_always() && !is_default_update(set.source) {
			return sqlstate_428c9(set.column_name)
		}
	}
	for column in c.columns {
		table.column(column.sub_entity_name)!
	}
}

// arbiters are the PRIMARY KEY, UNIQUE constraints and UNIQUE indexes that the
// conflict target names. A column list matches each one that has exactly those
// columns (in any order). It's an error when none match, or one of them is
// DEFERRABLE, since a deferred constraint can have duplicates until it's
// checked.
fn (c OnConflict) arbiters(mut storage Storage, table Table) ![]ConflictArbiter {
	mut candidates := []ConflictArbiter{}
	if table.primary_key.len > 0 {
		candidates << ConflictArbiter{
			name:           table.primary_key_name
			columns:        table.primary_key
			nulls_distinct: true
			is_constraint:  true
			deferrable:     table.primary_key_characteristics.is_deferrable()
		}
	}
	for constraint in table.unique_constraints {
		candidates << ConflictArbiter{
			name:           constraint.name
			columns:        constraint.columns
			index:          storage.constraint_index(table, constraint)!
			nulls_distinct: !constraint.nulls_not_distinct
			is_constraint:  true
			deferrable:     constraint.characteristics.is_deferrable()
		}
	}
	for index in storage.table_indexes(table.id) {
		if index.unique && !table.is_constraint_index(index) {
			candidates << ConflictArbiter{
				name:           index.name.entity_name
				columns:        index.columns.map(it.name)
				index:          index
				nulls_distinct: true
			}
		}
	}

	mut arbiters := candidates.clone()
	if c.columns.len > 0 {
		mut target := c.columns.map(it.sub_entity_name)
		target.sort()
		arbiters = candidates.filter(fn [target] (a ConflictArbiter) bool {
			mut columns := a.columns.clone()
			columns.sort()
			return columns == target
		})
		if arbiters.len == 0 {
			return sqlstate_42601('there is no PRIMARY KEY, UNIQUE constraint or UNIQUE index on ${table.name} for ON CONFLICT (${c.columns.map(requote_identifier(it.sub_entity_name)).join(', ')})')
		}
	} else if c.constraint_name != '' {
		arbiters = candidates.filter(it.is_constraint && it.name == c.constraint_name)
		if arbiters.len == 0 {
			return sqlstate_42704('constraint', '${c.constraint_name} on ${table.name}')
		}
	}

	for arbiter in arbiters {
		if arbiter.deferrable {
			return sqlstate_42601('ON CONFLICT cannot use ${requote_identifier(arbiter.name)} on ${table.name}, because it is DEFERRABLE')
		}
	}

	return arbiters
}

// tables are the tables that the DO UPDATE can use: the table, and the row that
// would have been inserted, as EXCLUDED.
fn (c OnConflict) tables(table_name Identifier, table Table) map[string]&Table {
	return {
		table_name.id(): &table
		excluded_table:  &Table{
			name:    Identifier{
				entity_name: excluded_table
			}
			columns: table.columns.map(Column{
				...it
				name: Identifier{
					entity_name:     excluded_table
					sub_entity_name: it.name.sub_entity_name
				}
			})
		}
	}
}

// source_row is the row that the DO UPDATE is evaluated with: the existing row
// (with its id and version, which is what's updated), and the row that would
// have been inserted as EXCLUDED.
fn source_row(target_id string, table Table, existing Row, excluded Row) Row {
	mut data := map[string]Value{}
	for column in table.columns {
		name := column.name.sub_entity_name
		data['${target_id}.${name}'] = existing.data.value(name)
		data['${excluded_table}.${name}'] = excluded.data.value(name)
	}

	return Row{
		...new_row(data)
		id:  existing.id
		tid: existing.tid
	}
}

// change writes each new row, unless it conflicts with a row of the table (or
// a row that this INSERT already inserted or updated) in one of the arbiters.
// Then it's skipped, or that row is updated instead. The rows are checked one
// at a time, in order. A row can't be updated twice, since the result would
// depend on the order of the rows. The other constraints are checked once
// every row has been written, like an INSERT and UPDATE. The new rows are the
// rows that were inserted or updated.
fn (c OnConflict) change(mut conn Connection, params map[string]Value, table_name Identifier, table Table, rows []Row) !DataChange {
	c.check(table)!
	mut catalog := conn.catalog_for(table_name)
	arbiters := c.arbiters(mut catalog.storage, table)!

	target_id := table_name.id()
	tables := c.tables(table_name, table)
	mut ctx := MergeContext{
		table:     table
		target_id: target_id
		tables:    tables
		params:    params
		check:     new_check_constraints(mut conn, table)!
		generated: new_generated_columns(mut conn, table)!
	}
	clause := MergeWhenClause{
		matched: true
		set:     c.set
	}
	mut condition := ?CompileResult(none)
	if expr := c.condition {
		mut compiler := Compiler{
			conn:   conn
			params: params
			tables: tables
		}
		condition = expr.compile(mut compiler)!
	}

	mut changed := map[string]bool{}
	mut inserts := []Row{}
	mut subject_rows := []Row{}
	mut changes := []RowChange{}
	mut new_rows := []Row{}
	for row in rows {
		mut existing := Row{}
		mut found := false
		for arbiter in arbiters {
			existing, found = catalog.storage.conflicting_row(table, arbiter, row)!
			if found {
				break
			}
		}

		if !found {
			mut inserted := row
			catalog.storage.write_row(mut inserted, table)!
			changed[inserted.id.bytestr()] = true
			inserts << inserted
			new_rows << inserted
			continue
		}

		if !c.do_update {
			continue
		}

		if existing.id.bytestr() in changed {
			return sqlstate_21000('ON CONFLICT DO UPDATE cannot change the same row of ${table.name} more than once')
		}

		source := source_row(target_id, table, existing, row)
		if compiled := condition {
			value := compiled.run(mut conn, source, params)!
			if value.is_null || value.bool_value() != .is_true {
				continue
			}
		}

		// A row that doesn't change isn't written, but it's still counted.
		change, did_modify := ctx.update(mut conn, source, 0, clause)!
		subject_rows << existing
		if !did_modify {
			changed[existing.id.bytestr()] = true
			new_rows << existing
			continue
		}

		mut before := change.old
		mut after := change.new
		if before.object_key(table)! != after.object_key(table)! {
			catalog.storage.delete_row(table_name.storage_id(), mut before)!
			catalog.storage.write_row(mut after, table)!
		} else {
			catalog.storage.update_row(before, mut after, table)!
		}
		changed[after.id.bytestr()] = true
		changes << RowChange{
			old: before
			new: after
		}
		new_rows << after
	}

	apply_referential_actions(mut conn, mut catalog.storage, table, changes)!
	catalog.storage.check_unique_indexes(table, inserts)!
	catalog.storage.check_unique_constraints(table, inserts)!
	catalog.storage.check_foreign_keys(mut conn, table, inserts)!
	conn.note_row_changes(table, subject_rows, changes, none)!

	if rows.len == 0 {
		conn.add_warning(sqlstate_02000())
	}

	return DataChange{
		new: new_rows
	}
}

// conflicting_row is the row of t that row has the same values as in the
// columns of the arbiter, if there is one. That includes a row that the current
// transaction has written, but not one that another transaction is creating or
// deleting, which is an error since it might or might not exist once that
// transaction finishes (like a PRIMARY KEY or UNIQUE constraint).
fn (mut f Storage) conflicting_row(t Table, arbiter ConflictArbiter, row Row) !(Row, bool) {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut r := row
	mut key := row_key_prefix(t.id)
	if index := arbiter.index {
		entry, found := f.find_entry(index, t, r, arbiter.nulls_distinct, []u8{})!
		if !found {
			return Row{}, false
		}
		key << index.entry_row_id(t, entry)!
	} else {
		// The PRIMARY KEY is the key of the row, so a row with the same key
		// already exists when it's violated.
		mut found := false
		f.check_primary_key(mut r, t) or {
			if err !is SQLState23505 {
				return err
			}
			found = true
		}
		if !found {
			return Row{}, false
		}
		key = r.object_key(t)!
	}

	object := f.read_objects(key, key)![0]

	return new_row_from_bytes(t, object.value, object.tid).for_storage(), true
}
