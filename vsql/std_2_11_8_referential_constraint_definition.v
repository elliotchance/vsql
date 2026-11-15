module vsql

// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>
//
// Specify a referential constraint.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.25.3.3, Referential constraints

// A FOREIGN KEY, or a REFERENCES on a column. The referenced_columns are empty
// when they aren't given, which means the PRIMARY KEY of the referenced table.
// The match_type, update_rule and delete_rule are empty when there's no MATCH,
// ON UPDATE or ON DELETE.
//
// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 1 and 4.b
struct ReferentialConstraintDefinition {
	name               Identifier
	columns            []Identifier
	referenced_table   Identifier
	referenced_columns []Identifier
	match_type         string // SIMPLE, PARTIAL or FULL
	update_rule        string // CASCADE, SET NULL, SET DEFAULT, RESTRICT or NO ACTION
	delete_rule        string // CASCADE, SET NULL, SET DEFAULT, RESTRICT or NO ACTION
	characteristics    ConstraintCharacteristics
}

fn new_referential_constraint_definition(columns []Identifier, references ReferentialConstraintDefinition) ReferentialConstraintDefinition {
	return ReferentialConstraintDefinition{
		...references
		columns: columns
	}
}

// A ForeignKey is a referential constraint of a table. Once the table has been
// created, the referenced_table is fully qualified and the referenced_columns
// are always known (see resolve_foreign_keys), in the order of the columns that
// they correspond to. The match_type is empty for MATCH SIMPLE, and the
// update_rule and delete_rule are empty for NO ACTION.
struct ForeignKey {
	name               string
	columns            []string
	referenced_table   Identifier
	referenced_columns []string
	match_type         string // PARTIAL or FULL
	update_rule        string // CASCADE, SET NULL, SET DEFAULT or RESTRICT
	delete_rule        string // CASCADE, SET NULL, SET DEFAULT or RESTRICT
	characteristics    ConstraintCharacteristics
}

// str is how the constraint is stored in the file as part of the CREATE TABLE
// (see Table.bytes).
fn (k ForeignKey) str() string {
	mut s := 'FOREIGN KEY (${k.columns.map(delimit_identifier(it)).join(', ')}) REFERENCES ${k.referenced_table.storage_sql()} (${k.referenced_columns.map(delimit_identifier(it)).join(', ')})'
	if k.match_type != '' {
		s += ' MATCH ${k.match_type}'
	}
	if k.update_rule != '' {
		s += ' ON UPDATE ${k.update_rule}'
	}
	if k.delete_rule != '' {
		s += ' ON DELETE ${k.delete_rule}'
	}

	return s + k.characteristics.str()
}

// update_action is the referential action of the ON UPDATE.
fn (k ForeignKey) update_action() string {
	return if k.update_rule == '' { 'NO ACTION' } else { k.update_rule }
}

// delete_action is the referential action of the ON DELETE.
fn (k ForeignKey) delete_action() string {
	return if k.delete_rule == '' { 'NO ACTION' } else { k.delete_rule }
}

// is_referencing is true if a row must reference a row of the referenced
// table. With MATCH SIMPLE, a row with a NULL in any of the columns doesn't,
// and with MATCH PARTIAL or FULL, a row where every column is NULL doesn't.
//
// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 18.b
fn (k ForeignKey) is_referencing(row Row) bool {
	nulls := k.columns.filter(row.data.value(it).is_null).len

	return if k.match_type == '' { nulls == 0 } else { nulls < k.columns.len }
}

// has_null is true if any column of the FOREIGN KEY is NULL in row.
fn (k ForeignKey) has_null(row Row) bool {
	return k.columns.any(row.data.value(it).is_null)
}

// is_partial_match is true if each column of row (a row of the referencing
// table) that isn't NULL has the same value as the corresponding column of
// referenced (a row of the referenced table), which is how MATCH PARTIAL finds
// the rows that a row references. The values are compared as their key types
// (see key_value).
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 6.b.i
fn (k ForeignKey) is_partial_match(row Row, referenced Row, types []SQLType, time_zone i16) bool {
	for i, column in k.columns {
		if !row.data.value(column).is_null && key_value(row, [column], [types[i]], time_zone) != key_value(referenced,
			[k.referenced_columns[i]], [types[i]], time_zone) {
			return false
		}
	}

	return true
}

// violation is the error for a row of t (the referencing table) that doesn't
// reference a row of the referenced table.
fn (k ForeignKey) violation(t Table) IError {
	return sqlstate_23503('FOREIGN KEY (${k.columns.map(requote_identifier(it)).join(', ')}) REFERENCES ${k.referenced_table} (${k.referenced_columns.map(requote_identifier(it)).join(', ')}) on ${t.name}',
		t.constraint_identifier(k.name), t.name)
}

// resolve_foreign_keys finds the table and columns that each FOREIGN KEY of a
// new definition of table references, and checks them. The referenced table
// can be the table itself, and must be a base table. It must be in the same
// catalog, because each catalog is a separate file.
//
// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 5, 6 and 15
fn resolve_foreign_keys(mut conn Connection, mut table Table) ! {
	for i, key in table.foreign_keys {
		mut name := conn.resolve_identifier(key.referenced_table)
		if name.catalog_name != table.name.catalog_name {
			return sqlstate_0a000('FOREIGN KEY cannot reference a table in another catalog: ${name}')
		}

		referenced := if name.storage_id() == table.name.storage_id() {
			table
		} else {
			name = conn.resolve_table_identifier(name, false)!
			conn.catalog_for(name).storage.table(name.storage_id())
		}

		// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 4.b
		mut referenced_columns := key.referenced_columns.clone()
		if referenced_columns.len == 0 {
			if referenced.primary_key.len == 0 {
				return sqlstate_42830('${name} has no PRIMARY KEY')
			}
			referenced_columns = referenced.primary_key.clone()
		}

		// This is also the assertion of ISO/IEC 9075-11:2006, 6.2,
		// EQUAL_KEY_DEGREES assertion.
		//
		// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 11
		if referenced_columns.len != key.columns.len {
			return sqlstate_42830('FOREIGN KEY has ${key.columns.len} ${pluralize(key.columns.len, 'column')} but REFERENCES ${name} has ${referenced_columns.len}')
		}

		// A generated column can't be changed by a referential action, but
		// RESTRICT doesn't change it.
		//
		// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 14
		for column in key.columns {
			if table.column(column)!.generated == none {
				continue
			}
			action := if key.update_rule !in ['', 'RESTRICT'] {
				'ON UPDATE ${key.update_rule}'
			} else if key.delete_rule in ['SET NULL', 'SET DEFAULT'] {
				'ON DELETE ${key.delete_rule}'
			} else {
				continue
			}
			return sqlstate_42601('FOREIGN KEY on generated column ${column} cannot use ${action}')
		}

		// The referenced columns must be the columns of a unique constraint,
		// in any order. Every type can be grouped.
		//
		// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 4.a and 9
		for j, column in referenced_columns {
			typ := referenced.column(column)!.typ
			referencing_typ := table.column(key.columns[j])!.typ
			if !is_comparable_key_type(typ, referencing_typ) {
				return sqlstate_42804('in FOREIGN KEY', typ.str(), referencing_typ.str())
			}
		}

		mut sorted := referenced_columns.clone()
		sorted.sort()
		mut found := false
		mut primary_key := referenced.primary_key.clone()
		primary_key.sort()
		if primary_key.len > 0 && primary_key == sorted {
			// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 5
			if referenced.primary_key_characteristics.is_deferrable() {
				return sqlstate_42830('FOREIGN KEY cannot reference a DEFERRABLE constraint: ${referenced.primary_key_name}')
			}
			found = true
		}
		for constraint in referenced.unique_constraints {
			mut sorted_unique := constraint.columns.clone()
			sorted_unique.sort()
			if sorted_unique == sorted {
				// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 5
				if constraint.characteristics.is_deferrable() {
					return sqlstate_42830('FOREIGN KEY cannot reference a DEFERRABLE constraint: ${constraint.name}')
				}
				found = true
			}
		}

		if !found {
			return sqlstate_42830('there is no PRIMARY KEY or UNIQUE (${referenced_columns.map(requote_identifier(it)).join(', ')}) on ${name}')
		}

		table.foreign_keys[i] = ForeignKey{
			...key
			referenced_table:   name
			referenced_columns: referenced_columns
		}
	}
}

// key_type is the same for types that can be compared as keys, because a value
// of one type has the same key (see write_key_value) as the same value of the
// other type.
fn key_type(typ SQLType) SQLType {
	return match typ {
		.is_smallint, .is_integer, .is_bigint { .is_bigint }
		.is_real, .is_double_precision { .is_double_precision }
		.is_numeric, .is_decimal { .is_numeric }
		.is_character, .is_varchar, .is_clob { .is_varchar }
		.is_binary, .is_varbinary, .is_blob { .is_varbinary }
		else { typ }
	}
}

// is_comparable_key_type is true if a referencing column of type a can reference
// a column of type b. They must be comparable, so any two numeric types, and
// datetimes with the same datetime fields, can be used (Feature T201). Both or
// neither of the datetimes must have a time zone.
//
// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 11
fn is_comparable_key_type(a Type, b Type) bool {
	return key_type(a.typ) == key_type(b.typ) || (a.typ.is_number() && b.typ.is_number())
}

// foreign_key_type is the type that the values of a referencing column of type
// a and its referenced column of type b are compared as. An exact numeric is
// compared with an approximate numeric as a DOUBLE PRECISION, and a datetime
// without a time zone is compared with one with a time zone in UTC, like any
// other comparison.
//
// ISO/IEC 9075-2:2023, 8.2, <comparison predicate>, General Rules, 2 and 6
fn foreign_key_type(a SQLType, b SQLType) SQLType {
	ka, kb := key_type(a), key_type(b)
	if ka == kb {
		return ka
	}

	if a.is_datetime() {
		return if datetime_fields(a) == 'TIME' {
			SQLType.is_time_with_time_zone
		} else {
			SQLType.is_timestamp_with_time_zone
		}
	}

	if ka == .is_double_precision || kb == .is_double_precision {
		return .is_double_precision
	}

	return .is_numeric
}

// check_foreign_keys returns an error if a row in rows doesn't reference a row
// of the referenced table of each FOREIGN KEY of t, or might not once another
// transaction finishes. Only some rows need to reference a row (see
// is_referencing), and a row with some (but not all) NULLs never does with
// MATCH FULL. With MATCH PARTIAL, a row with a NULL is found by reading every
// row of the referenced table (see is_partial_match), and another transaction
// writing any of its rows is an error (see read_existing_rows). Like
// check_unique_constraints, the rows must have already been written, so a row
// can reference a row of the same table that's written by the same statement.
// A deferred constraint isn't checked (see defer_check).
//
// The referenced row is found by its PRIMARY KEY, or the index of its UNIQUE
// constraint (see referenced_range), so only the rows (or entries) with the
// same key are read.
//
// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 18
fn (mut f Storage) check_foreign_keys(mut conn Connection, t Table, rows []Row) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// The time zone of the statement, rather than conn.now(), which would read
	// the clock again.
	time_zone := conn.statement_time_zone
	for key in t.foreign_keys {
		referencing_rows := rows.filter(key.is_referencing(it))
		if referencing_rows.len == 0 || f.defer_check(t, key.name, key.characteristics) {
			continue
		}

		// A row that another transaction is writing only matters if there
		// isn't another row with the same key, so the result doesn't depend on
		// the order of the rows.
		referenced := f.table(key.referenced_table.storage_id())
		types := foreign_key_types(t, key.columns, referenced, key.referenced_columns)!
		has_nulls := referencing_rows.any(key.has_null(it))
		partial_rows := if has_nulls && key.match_type == 'PARTIAL' {
			f.read_existing_rows(referenced)!
		} else {
			[]Row{}
		}
		mut is_missing := false
		mut is_concurrent := false
		for row in referencing_rows {
			// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 18.b.ii and 18.b.iii
			if key.has_null(row) {
				is_missing = is_missing || key.match_type == 'FULL'
					|| !partial_rows.any(key.is_partial_match(row, it, types, time_zone))
				continue
			}

			// A value that the referenced column can't hold can't be
			// referenced.
			search := search_row(mut conn, row, key.columns, referenced, key.referenced_columns) or {
				is_missing = true
				continue
			}
			start, end := f.referenced_range(key, referenced, search)!
			found, concurrent := f.find_objects(start, end)!
			if !found {
				is_missing = true
				is_concurrent = is_concurrent || concurrent
			}
		}

		if is_concurrent {
			return sqlstate_40001('avoiding concurrent write on individual row')
		}

		if is_missing {
			return key.violation(t)
		}
	}
}

// search_row is a row of to_table that has the values of the from_columns of
// row (of the same or another table) in its to_columns, to find the rows of
// to_table that have the same key. It's none when a value can't be held
// exactly by its column of to_table (see exact_cast), so no row of to_table can
// have the same key. None of the values can be NULL.
fn search_row(mut conn Connection, row Row, from_columns []string, to_table Table, to_columns []string) ?Row {
	mut data := RowData{}
	for i, column in to_columns {
		typ := (to_table.column(column) or { return none }).typ
		data.set(column, exact_cast(mut conn, row.data.value(from_columns[i]), typ) or { return none })
	}

	return Row{
		data: data
	}
}

// referenced_range is the range of keys (inclusive) of the rows of referenced
// that have the values of search in the referenced columns of the FOREIGN KEY,
// when they're the PRIMARY KEY. Otherwise, it's the range of the entries of the
// index of the UNIQUE constraint that has those columns (see
// resolve_foreign_keys and constraint_index).
fn (mut f Storage) referenced_range(key ForeignKey, referenced Table, search Row) !([]u8, []u8) {
	if is_same_columns(referenced.primary_key, key.referenced_columns) {
		mut r := search
		row_key := r.object_key(referenced)!
		return row_key, row_key
	}

	constraint := referenced.unique_constraints.filter(is_same_columns(it.columns, key.referenced_columns))[0]
	index := f.constraint_index(referenced, constraint)!
	values := index.entry_values(referenced, search)!

	return values, next_key(values)
}

// is_same_columns is true when a and b have the same columns, in any order.
fn is_same_columns(a []string, b []string) bool {
	mut sorted_a := a.clone()
	sorted_a.sort()
	mut sorted_b := b.clone()
	sorted_b.sort()

	return sorted_a == sorted_b
}

// find_objects reads the objects (rows or index entries) from start to end
// (inclusive). It's found when one of them exists (it hasn't been deleted by
// this or a committed transaction), and concurrent when another transaction is
// creating or deleting one, so it might or might not exist once that
// transaction finishes. It must be called from inside an isolation block.
fn (mut f Storage) find_objects(start []u8, end []u8) !(bool, bool) {
	mut found := false
	mut concurrent := false
	mut iter := f.btree.new_range_iterator(start, end)
	for {
		object := iter.next() or { break }
		if f.is_concurrent_write(object) {
			concurrent = true
		} else if object.xid == 0 {
			found = true
		}
	}
	if err := iter.err {
		return err
	}

	return found, concurrent
}

// read_existing_rows are the rows of t that exist (see
// read_existing_objects). It's an error if another transaction is writing any
// of them. Every row is read, so it's only used for MATCH PARTIAL, where a row
// with a NULL can't be found by its key.
fn (mut f Storage) read_existing_rows(t Table) ![]Row {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	return f.read_existing_objects(row_key_prefix(t.id), row_key_prefix(t.id + 1))!.map(new_row_from_bytes(t,
		it.value, it.tid).for_storage())
}

// referencing_prefix is the start of the key of every entry of the index that
// a FOREIGN KEY of referencing uses (see foreign_key_index) for the rows that
// reference row (a row of the referenced table). It's empty when no row of
// referencing can reference it, because the referencing columns can't hold the
// key exactly (see search_row). None of the values of the key can be NULL.
fn (mut f Storage) referencing_prefix(mut conn Connection, key ForeignKey, referencing Table, row Row) ![]u8 {
	search := search_row(mut conn, row, key.referenced_columns, referencing, key.columns) or {
		return []u8{}
	}
	index := f.foreign_key_index(referencing, key)!

	return index.entry_prefix(referencing, search, key.columns.len)!
}

// check_referencing_rows returns an error if a row of a table that references
// t (including t itself) references a key that's in old_rows but not new_rows,
// or might once another transaction finishes. The old_rows are the rows of t
// that a statement deleted or updated, and new_rows are the rows that it wrote.
// The referential actions (see apply_referential_actions) have already been
// carried out, so it's checked once the whole statement has finished.
//
// ISO/IEC 9075-2:2023, 4.25.2, Checking of constraints
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions
// ISO/IEC 9075-2:2023, 9.17, Executing an <SQL procedure statement>, General Rules, 15 and 17.a
//
// The referenced columns are a unique constraint (which has already been
// checked), so another row of t can't have the same key. A datetime without a
// time zone is in the session time zone (time_zone, in minutes) when it's
// compared with one with a time zone. Only the entries of the index of each
// FOREIGN KEY (see foreign_key_index) that have a removed key are read. A
// deferred constraint isn't checked (see defer_check), it's checked against
// every referencing row instead.
fn (mut f Storage) check_referencing_rows(mut conn Connection, t Table, old_rows []Row, new_rows []Row, time_zone i16) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// The tables are sorted so that the same error is always returned.
	mut table_names := f.tables.keys()
	table_names.sort()
	for table_name in table_names {
		if !f.references(table_name, t.name.storage_id()) {
			continue
		}

		referencing := f.table(table_name)
		for key in referencing.foreign_keys {
			if key.referenced_table.storage_id() != t.name.storage_id() {
				continue
			}

			types := foreign_key_types(referencing, key.columns, t, key.referenced_columns)!
			if key.match_type == 'PARTIAL' {
				if old_rows.len > 0 && !f.defer_check(referencing, key.name, key.characteristics) {
					f.check_partial_references(key, referencing, t, types, old_rows, time_zone)!
				}
				continue
			}

			mut removed := map[string]Row{}
			for row in old_rows {
				value := key_value(row, key.referenced_columns, types, time_zone)
				if value.len > 0 {
					removed[value.bytestr()] = row
				}
			}
			for row in new_rows {
				removed.delete(key_value(row, key.referenced_columns, types, time_zone).bytestr())
			}
			if removed.len == 0 || f.defer_check(referencing, key.name, key.characteristics) {
				continue
			}

			// A row that references a removed key is an error, even if another
			// transaction is also writing a row that references it.
			mut is_concurrent := false
			for _, row in removed {
				prefix := f.referencing_prefix(mut conn, key, referencing, row)!
				if prefix.len == 0 {
					continue
				}
				found, concurrent := f.find_objects(prefix, next_key(prefix))!
				if found {
					return key.violation(referencing)
				}
				is_concurrent = is_concurrent || concurrent
			}

			if is_concurrent {
				return sqlstate_40001('avoiding concurrent write on individual row')
			}
		}
	}
}

// check_partial_references is check_referencing_rows for a FOREIGN KEY of
// referencing with MATCH PARTIAL. A row that matched one of the old rows of t
// must still match a row of t (see is_partial_match), so every row of both
// tables is read.
//
// ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Syntax Rules, 18.b.ii
fn (mut f Storage) check_partial_references(key ForeignKey, referencing Table, t Table, types []SQLType, old_rows []Row, time_zone i16) ! {
	referenced := f.read_existing_rows(t)!
	for row in f.read_existing_rows(referencing)! {
		if key.is_referencing(row) && old_rows.any(key.is_partial_match(row, it, types, time_zone))
			&& !referenced.any(key.is_partial_match(row, it, types, time_zone)) {
			return key.violation(referencing)
		}
	}
}

// A RowChange is a row of a table that a statement (or a referential action)
// deleted or replaced. The new row is only used when it isn't a delete.
struct RowChange {
	old       Row
	new       Row
	is_delete bool
}

// ChangedSites are the sites (columns of rows) that the referential actions of
// a statement have updated, and the rows that they've deleted. A referential
// action can't update a site to a different value than it was already updated
// to, or update or delete a row that was deleted or updated (a triggered data
// change violation).
//
// The changes made by the statement itself aren't included. The matching rows
// are found when each action is carried out, rather than before the statement
// (General Rule 7), so a row that the statement deleted can't be matched, and
// a site that it updated is only matched by its new value.
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 12 and 13
struct ChangedSites {
mut:
	// updated is the value that each column was updated to, by the table and
	// the object key of the row.
	updated map[string]map[string]Value
	// deleted are the rows that were deleted from each table.
	deleted map[string][]Row
}

fn changed_site_key(table Table, row Row) !string {
	mut r := row

	return '${table.name.storage_id()}/${r.object_key(table)!.bytestr()}'
}

// add records the rows that a referential action deleted or replaced, where
// columns are the columns that it updated.
fn (mut s ChangedSites) add(conn &Connection, table Table, changes []RowChange, columns []string) ! {
	// The keys of the rows are from before any of them changed, since a row
	// can get the PRIMARY KEY of another row (see UpdateStatementSearched).
	mut updated := map[string]map[string]Value{}
	mut before_keys := []string{}
	for change in changes {
		before := changed_site_key(table, change.old)!
		before_keys << before
		mut sites := (s.updated[before] or { map[string]Value{} }).clone()
		if change.is_delete {
			if sites.len > 0 {
				return sqlstate_27000('a row of ${table.name} that was updated is deleted')
			}
			unsafe {
				s.deleted[table.name.storage_id()] << change.old
			}
			continue
		}

		for column in columns {
			value := change.new.data.value(column)
			if previous := sites[column] {
				if is_distinct(conn, previous, value)! {
					return sqlstate_27000('column ${column} of a row of ${table.name} is updated to two different values')
				}
			}
			sites[column] = value
		}
		updated[changed_site_key(table, change.new)!] = sites
	}

	for key in before_keys {
		s.updated.delete(key)
	}
	for key, sites in updated {
		s.updated[key] = sites
	}
}

// is_distinct is true if the values are distinct (8.15, <distinct predicate>),
// where NULL isn't distinct from NULL.
fn is_distinct(conn &Connection, a Value, b Value) !bool {
	if a.is_null || b.is_null {
		return a.is_null != b.is_null
	}

	return compare(conn, a, b)! != .is_equal
}

// apply_referential_actions carries out the referential actions of the
// FOREIGN KEYs that reference t (including t itself) for the rows of t that a
// DELETE or UPDATE changed, and then checks the constraints of each table that
// has changed rows. A row that's deleted or replaced by a referential action
// can have its own referencing rows, so this repeats until there are no more
// changes. A row that's replaced by a referential action is checked like a row
// that's changed by an UPDATE.
//
// The rows of t must have already been written, and their UNIQUE and
// FOREIGN KEY constraints are checked here, after the referential actions,
// since a referential action can change a row of t when t references itself.
//
// The referencing tables are in the same catalog as t (see
// resolve_foreign_keys), so they're all in f.
//
// This always ends, even with a cycle of CASCADE keys. A change only causes
// more changes when it gives a referenced key a distinct value, which means
// updating a site. Each site can only be updated to one value (see
// ChangedSites), and there's a finite number of sites, so there can only be a
// finite number of rounds.
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 9, 10 and 17
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 12 and 13
fn apply_referential_actions(mut conn Connection, mut f Storage, t Table, changes []RowChange) ! {
	if changes.len == 0 {
		return
	}

	// Without a foreign key that references t there are no actions, and no rows
	// that reference the old rows, so only the new rows are checked (as below).
	if !f.is_referenced(t.name.storage_id()) {
		table := f.table(t.name.storage_id())
		mut rows := []Row{cap: changes.len}
		if changes.len == 1 {
			if !changes[0].is_delete {
				rows << changes[0].new
			}
		} else {
			mut written := map[string]Row{}
			for change in changes {
				if !change.is_delete {
					mut row := change.new
					written[row.object_key(t)!.bytestr()] = row
				}
			}
			rows = written.values()
		}
		f.check_unique_indexes(table, rows)!
		f.check_unique_constraints(table, rows)!
		f.check_foreign_keys(mut conn, table, rows)!
		return
	}

	_, time_zone := conn.session_now()
	mut sites := ChangedSites{}

	// The old rows of each table are the rows that were deleted or replaced,
	// and the written rows are the latest version of each row that was written
	// (by its object key).
	mut old := map[string][]Row{}
	mut written := map[string]map[string]Row{}
	for change in changes {
		unsafe {
			old[t.name.storage_id()] << change.old
		}
		if !change.is_delete {
			mut row := change.new
			key := row.object_key(t)!.bytestr()
			unsafe {
				written[t.name.storage_id()][key] = row
			}
		}
	}

	// The tables are sorted so that the rows are always changed in the same
	// order.
	mut table_names := f.tables.keys()
	table_names.sort()

	mut action_changes := map[string][]RowChange{}
	mut pending_tables := [t.name.storage_id()]
	mut pending_changes := [changes]
	for pending_tables.len > 0 {
		table := f.table(pending_tables.pop())
		table_changes := pending_changes.pop()

		for table_name in table_names {
			if !f.references(table_name, table.name.storage_id()) {
				continue
			}

			referencing := f.table(table_name)
			for key in referencing.foreign_keys {
				if key.referenced_table.storage_id() != table.name.storage_id() {
					continue
				}

				// A referenced row has an action when it's deleted, or when a
				// referenced column that isn't NULL is updated to a different
				// value (General Rules, 9 and 10). The actions are those
				// changes, except for the changes that RESTRICT doesn't allow
				// (restricted). keys are the old rows that have each deleted
				// or updated key, and changes are the changes of those rows,
				// for MATCH SIMPLE or FULL.
				types := foreign_key_types(referencing, key.columns, table, key.referenced_columns)!
				mut actions := []RowChange{}
				mut restricted := []RowChange{}
				for change in table_changes {
					rule := if change.is_delete {
						key.delete_rule
					} else if is_updated(key, change, types, time_zone) {
						key.update_rule
					} else {
						''
					}
					if rule == 'RESTRICT' {
						restricted << change
					} else if rule != '' {
						actions << change
					}
				}

				if restricted.len > 0 {
					f.check_restrict(mut conn, key, referencing, table, types, restricted,
						old[table_name] or { []Row{} }, time_zone)!
				}
				if actions.len == 0 {
					continue
				}
				mut keys := map[string]Row{}
				mut changes_by_key := map[string]RowChange{}
				for change in actions {
					value := key_value(change.old, key.referenced_columns, types, time_zone)
					if value.len > 0 {
						keys[value.bytestr()] = change.old
						changes_by_key[value.bytestr()] = change
					}
				}

				// A row that was deleted can't also be updated by an action
				// (General Rule 13). It's no longer stored, so it isn't one
				// of the matching rows.
				referenced_rows := if key.match_type == 'PARTIAL' {
					f.read_existing_rows(table)!
				} else {
					[]Row{}
				}
				for m in key.referential_matches(sites.deleted[table_name] or { []Row{} }, referenced_rows,
					actions, changes_by_key, types, time_zone) {
					if !m.referenced.is_delete || key.delete_rule != 'CASCADE' {
						return sqlstate_27000('a row of ${referencing.name} that was deleted is updated')
					}
				}

				matching := key.referential_matches(if key.match_type == 'PARTIAL' {
					f.read_existing_rows(referencing)!
				} else {
					f.matching_rows(mut conn, key, referencing, types, keys, time_zone)!
				}, referenced_rows, actions, changes_by_key, types, time_zone)
				if matching.len == 0 {
					continue
				}

				check_constraints := new_check_constraints(mut conn, referencing)!
				generated_columns := new_generated_columns(mut conn, referencing)!
				mut new_changes := []RowChange{}
				for m in matching {
					row := m.row
					rule := if m.referenced.is_delete { key.delete_rule } else { key.update_rule }
					if rule == 'CASCADE' && m.referenced.is_delete {
						new_changes << RowChange{
							old:       row
							is_delete: true
						}
						continue
					}

					mut after := Row{
						id:   row.id
						tid:  row.tid
						data: row.data.clone()
					}
					for i in key.changed_columns(m, types, time_zone) {
						column_name := key.columns[i]
						column := referencing.column(column_name)!
						new_value := match rule {
							'CASCADE' {
								v := cast(mut conn, 'for column ${column_name}', m.referenced.new.data.value(key.referenced_columns[i]),
									column.typ)!
								if column.not_null && v.is_null {
									return sqlstate_23502(referencing, column_name)
								}
								v
							}
							'SET NULL' {
								insert_value(mut conn, map[string]Value{}, referencing, column, ContextuallyTypedValueSpecification(NullSpecification{}))!
							}
							else {
								insert_value(mut conn, map[string]Value{}, referencing, column, ContextuallyTypedValueSpecification(DefaultSpecification{}))!
							}
						}
						after.data.set(column_name, new_value)
					}
					generated_columns.apply(mut conn, mut after)!
					check_constraints.verify(mut conn, after)!
					new_changes << RowChange{
						old: row
						new: after
					}
				}

				sites.add(conn, referencing, new_changes, key.columns)!

				// Like an UPDATE, a row that gets a new PRIMARY KEY is deleted
				// and only written again once all of the rows have been
				// deleted.
				mut moved := []Row{}
				for change in new_changes {
					mut before := change.old
					unsafe {
						old[table_name] << before
					}
					before_key := before.object_key(referencing)!.bytestr()
					unsafe {
						written[table_name].delete(before_key)
					}
					if change.is_delete {
						f.delete_row(table_name, mut before)!
						continue
					}

					mut after := change.new
					if before.object_key(referencing)! != after.object_key(referencing)! {
						f.delete_row(table_name, mut before)!
						moved << after
					} else {
						f.update_row(before, mut after, referencing)!
						after_key := after.object_key(referencing)!.bytestr()
						unsafe {
							written[table_name][after_key] = after
						}
					}
				}
				for mut row in moved {
					f.write_row(mut row, referencing)!
					row_key := row.object_key(referencing)!.bytestr()
					unsafe {
						written[table_name][row_key] = row
					}
				}

				unsafe {
					action_changes[table_name] << new_changes
				}
				pending_tables << table_name
				pending_changes << new_changes
			}
		}
	}

	for table_name in table_names {
		// The checks only look at the rows that were changed, and each row
		// that was written replaced an old one.
		if table_name !in old {
			continue
		}

		table := f.table(table_name)
		rows := (written[table_name] or { map[string]Row{} }).values()
		f.check_unique_indexes(table, rows)!
		f.check_unique_constraints(table, rows)!
		f.check_foreign_keys(mut conn, table, rows)!
		f.check_referencing_rows(mut conn, table, old[table_name] or { []Row{} }, rows, time_zone)!
	}

	for table_name in table_names {
		table_changes := action_changes[table_name] or { []RowChange{} }
		conn.note_row_changes(f.table(table_name), table_changes.map(it.old), table_changes,
			none)!
	}
}

// check_restrict returns an error (23001) if a row of the referencing table
// references one of the keys that RESTRICT doesn't allow to be deleted or
// updated, where keys has a row of the referenced table with each key. Unlike
// NO ACTION, this is checked straight away, before any other referential
// actions, and even when the FOREIGN KEY is deferred.
//
// The matching rows are the rows from before the statement (General Rule 7),
// so a row of the referencing table that this statement (or one of its
// referential actions) has already deleted or replaced is also a matching row.
// Those are the old rows of the referencing table. For example, a DELETE of
// every row of a table that references itself is still an error.
//
// With MATCH PARTIAL, only a unique matching row is an error (see
// is_restricted_partial).
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 9.a.iv, 9.b.iv, 10.a.iv and 10.b.iv
fn (mut f Storage) check_restrict(mut conn Connection, key ForeignKey, referencing Table, referenced Table, types []SQLType, restricted []RowChange, old []Row, time_zone i16) ! {
	mut is_matched := false
	if key.match_type == 'PARTIAL' {
		mut rows := old.clone()
		rows << f.read_existing_rows(referencing)!
		is_matched = key.is_restricted_partial(rows, referenced, f.read_existing_rows(referenced)!,
			restricted, types, time_zone)!
	} else {
		mut keys := map[string]Row{}
		for change in restricted {
			value := key_value(change.old, key.referenced_columns, types, time_zone)
			if value.len > 0 {
				keys[value.bytestr()] = change.old
			}
		}
		is_matched = keys.len > 0
			&& (old.any(key_value(it, key.columns, types, time_zone).bytestr() in keys)
				|| f.matching_rows(mut conn, key, referencing, types, keys, time_zone)!.len > 0)
	}

	if is_matched {
		return sqlstate_23001('FOREIGN KEY (${key.columns.map(requote_identifier(it)).join(', ')}) REFERENCES ${key.referenced_table} (${key.referenced_columns.map(requote_identifier(it)).join(', ')}) on ${referencing.name}',
			referencing.constraint_identifier(key.name), referencing.name)
	}
}

// is_restricted_partial is true if one of rows (of the referencing table) is a
// unique matching row of the old row of one of the restricted changes, for
// MATCH PARTIAL. That's a row that matches the old row (see is_partial_match),
// and doesn't match any other row of the referenced table (referenced_rows,
// which exist now). The association with every other row that was deleted or
// updated was dropped (General Rule 7), so they're not in referenced_rows. The
// new row of an update is the same row, so a row that still matches it (because
// the updated columns are NULL in the row) is still a unique matching row.
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 7, 9.b.iv and 10.b.iv
fn (k ForeignKey) is_restricted_partial(rows []Row, referenced Table, referenced_rows []Row, restricted []RowChange, types []SQLType, time_zone i16) !bool {
	for change in restricted {
		mut same := []u8{}
		if !change.is_delete {
			mut after := change.new
			same = after.object_key(referenced)!
		}
		mut others := []Row{}
		for row in referenced_rows {
			mut other := row
			if same.len == 0 || other.object_key(referenced)! != same {
				others << row
			}
		}

		for row in rows {
			if k.is_referencing(row) && k.is_partial_match(row, change.old, types, time_zone)
				&& !others.any(k.is_partial_match(row, it, types, time_zone)) {
				return true
			}
		}
	}

	return false
}

// A ReferentialMatch is a matching row of a referential action: a row of the
// referencing table that references a row of the referenced table that was
// deleted or updated.
struct ReferentialMatch {
	row        Row
	referenced RowChange
}

// is_updated is true if a referenced column of the FOREIGN KEY is updated by
// change (see is_updated_column).
fn is_updated(key ForeignKey, change RowChange, types []SQLType, time_zone i16) bool {
	for i, column in key.referenced_columns {
		if is_updated_column(change, column, types[i], time_zone) {
			return true
		}
	}

	return false
}

// is_updated_column is true if change updates a referenced column that isn't
// NULL to a different value (including NULL).
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 10
fn is_updated_column(change RowChange, column string, typ SQLType, time_zone i16) bool {
	old := key_value(change.old, [column], [typ], time_zone)

	return old.len > 0 && old != key_value(change.new, [column], [typ], time_zone)
}

// referential_matches are the rows (of the referencing table) that are matching
// rows of one of the actions (the changes of the referenced rows that have a
// referential action). With MATCH SIMPLE or FULL, a row matches the action that
// has the same key (in changes_by_key). With MATCH PARTIAL, only a unique
// matching row has an action, which is a row that matches the old row of an
// action, and doesn't match any row of the referenced table (referenced) now.
// The rows that match a deleted or updated row more than once only matched
// that row, because the association with every other row was dropped when it
// was deleted or updated (General Rule 7). A row that only matches the new row
// of an update isn't a matching row, but it can't have changed columns anyway
// (see changed_columns).
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 6 and 7
fn (k ForeignKey) referential_matches(rows []Row, referenced []Row, actions []RowChange, changes_by_key map[string]RowChange, types []SQLType, time_zone i16) []ReferentialMatch {
	mut matches := []ReferentialMatch{}
	for row in rows {
		if k.match_type != 'PARTIAL' {
			if change := changes_by_key[key_value(row, k.columns, types, time_zone).bytestr()] {
				matches << ReferentialMatch{row, change}
			}
			continue
		}

		if !k.is_referencing(row) || referenced.any(k.is_partial_match(row, it, types, time_zone)) {
			continue
		}
		for change in actions {
			if k.is_partial_match(row, change.old, types, time_zone) {
				matches << ReferentialMatch{row, change}
				break
			}
		}
	}

	return matches
}

// changed_columns are the indexes of the columns of the FOREIGN KEY that the
// referential action of m changes. A delete changes every column. An update
// only changes the columns that correspond to an updated referenced column
// (see is_updated_column), except that SET NULL with MATCH FULL changes every
// column. With MATCH PARTIAL, a column that's NULL is never changed.
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 9.a.ii.1, 9.a.iii.1, 9.b.ii.1 and 9.b.iii.1
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 10.a.i.1, 10.a.ii.1.A, 10.a.ii.2.A and 10.a.iii.1
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 10.b.i.1, 10.b.ii.1 and 10.b.iii.1
fn (k ForeignKey) changed_columns(m ReferentialMatch, types []SQLType, time_zone i16) []int {
	is_every_column := m.referenced.is_delete
		|| (k.match_type == 'FULL' && k.update_rule == 'SET NULL')
	mut columns := []int{}
	for i, column in k.columns {
		if is_every_column || (is_updated_column(m.referenced, k.referenced_columns[i], types[i],
			time_zone) && !m.row.data.value(column).is_null) {
			columns << i
		}
	}

	return columns
}

// matching_rows are the rows of the referencing table that reference one of
// the keys (see key_value) of the referenced table by the FOREIGN KEY, where
// keys has a row of the referenced table with each key. They're found with the
// index that the FOREIGN KEY uses (see referencing_prefix), and are in the
// order of the rows of the table. The matching rows are changed by the
// referential action, so it's an error if another transaction is writing one of
// them.
//
// ISO/IEC 9075-2:2023, 15.18, Execution of referential actions, General Rules, 6
fn (mut f Storage) matching_rows(mut conn Connection, key ForeignKey, referencing Table, types []SQLType, keys map[string]Row, time_zone i16) ![]Row {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	index := f.foreign_key_index(referencing, key)!
	mut matching := map[string]Row{}
	for _, referenced_row in keys {
		prefix := f.referencing_prefix(mut conn, key, referencing, referenced_row)!
		if prefix.len == 0 {
			continue
		}
		for entry in f.read_existing_objects(prefix, next_key(prefix))! {
			mut row_key := row_key_prefix(referencing.id)
			row_key << index.entry_row_id(referencing, entry.key)!
			for object in f.read_existing_objects(row_key, row_key)! {
				mut decoded := new_row_from_bytes(referencing, object.value, object.tid)
				row := f.resolve_row(mut decoded)!.for_storage()
				if key_value(row, key.columns, types, time_zone).bytestr() in keys {
					matching[row_key.bytestr()] = row
				}
			}
		}
	}

	mut row_keys := matching.keys()
	row_keys.sort()

	return row_keys.map(matching[it] or { Row{} })
}

// read_existing_objects are the objects (index entries or rows) from start to
// end (inclusive) that exist, which haven't been deleted by this or a committed
// transaction. It's an error if another transaction is creating or deleting
// one. It must be called from inside an isolation block.
fn (mut f Storage) read_existing_objects(start []u8, end []u8) ![]PageObject {
	mut objects := []PageObject{}
	mut iter := f.btree.new_range_iterator(start, end)
	for {
		object := iter.next() or { break }
		if f.is_concurrent_write(object) {
			return sqlstate_40001('avoiding concurrent write on individual row')
		}
		if object.xid == 0 {
			objects << object
		}
	}
	if err := iter.err {
		return err
	}

	return objects
}

// referencing_tables are the names of the other tables that reference t.
fn (f Storage) referencing_tables(t Table) []Identifier {
	mut names := []Identifier{}
	for _, table in f.tables {
		if table.name.storage_id() == t.name.storage_id() {
			continue
		}

		for key in table.foreign_keys {
			if key.referenced_table.storage_id() == t.name.storage_id() {
				names << table.name
				break
			}
		}
	}

	return names
}

// drop_foreign_keys_referencing drops the FOREIGN KEYs of the other tables that
// reference any of the tables (by their storage_id), which are being dropped by
// a DROP TABLE or DROP SCHEMA with CASCADE.
//
// ISO/IEC 9075-2:2023, 11.31, <drop table statement>, General Rules, 3
fn (mut f Storage) drop_foreign_keys_referencing(table_names []string) ! {
	// The tables are sorted so that they're always changed in the same order.
	mut names := f.tables.keys()
	names.sort()
	for name in names {
		if name in table_names {
			continue
		}

		mut table := f.table(name)
		keys := table.foreign_keys.filter(it.referenced_table.storage_id() !in table_names)
		if keys.len != table.foreign_keys.len {
			table.foreign_keys = keys
			f.update_table(table)!
		}
	}
}

// foreign_key_types are the types that the columns of a FOREIGN KEY of
// referencing and the columns of referenced are compared as (see
// foreign_key_type and key_value).
fn foreign_key_types(referencing Table, columns []string, referenced Table, referenced_columns []string) ![]SQLType {
	mut types := []SQLType{}
	for i, column in columns {
		types << foreign_key_type(referencing.column(column)!.typ.typ, referenced.column(referenced_columns[i])!.typ.typ)
	}

	return types
}
