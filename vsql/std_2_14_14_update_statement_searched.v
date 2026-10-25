module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>
//
// Update rows of a table.

struct UpdateStatementSearched {
	table_name Identifier
	set        []SetClause
	where      ?BooleanValueExpression
}

// UPDATE under MVCC works by actually executing a DELETE and an INSERT on the
// record to be updated. There are two important caveats for this:
//
// 1. If there is already two versions that exist for the record, UPDATE will
// return a SQLSTATE 40001 serialization failure to prevent multiple in-flight
// transactions form holding different modified version of the same semantic
// row. Clients that receive this error should retry the entire transaction.
//
// 2. If there are two versions that exist for a record but the in-flight
// version that exists belongs to this transaction we must avoid the
// DELETE/INSERT and only update the specific version that belongs to this
// transaction.
fn (stmt UpdateStatementSearched) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut set_columns := map[string]bool{}
	for clause in stmt.set {
		if clause.column_name in set_columns {
			return sqlstate_42601('column ${clause.column_name} is set more than once')
		}
		set_columns[clause.column_name] = true
	}

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut c := Compiler{
		conn:   conn
		params: params
	}
	mut plan := create_plan(stmt, params, mut conn)!
	mut rows := plan.execute([]Row{})!
	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())

	// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, Syntax Rule 5
	for clause in stmt.set {
		if identity := table.column(clause.column_name)!.identity {
			is_default := if clause.source is ContextuallyTypedValueSpecification {
				clause.source is DefaultSpecification
			} else {
				false
			}
			if identity.always && !is_default {
				return sqlstate_428c9(clause.column_name)
			}
		}
	}

	// The PRIMARY KEY is checked once all of the rows have changed, not after
	// each row. Otherwise, "SET id = id + 1" would fail on the old key of the
	// next row. So a row that gets a new key is deleted first, and only added
	// back after every row has been updated. UNIQUE and FOREIGN KEY constraints
	// are checked after that, see check_unique_constraints, check_foreign_keys
	// and check_referencing_rows.
	//
	// ISO/IEC 9075-2:2016(E), 4.23.2, Checking of constraints
	mut moved := []Row{}
	mut updated := []Row{}
	mut old := []Row{}
	check_constraints := new_check_constraints(mut conn, table)!

	// Every new row is found before any of them are written. Otherwise, a
	// subquery (such as "SET x = (SELECT MAX(x) FROM t)") would see the rows that
	// have already been updated.
	//
	// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, General Rule 10
	mut changes := [][]Row{}
	for mut row in rows {
		conn.begin_row()
		mut did_modify := false

		// When creating a new row make sure we also carry across the internal
		// ID. This allows the underlying storage to indentify it as a different
		// version of the same semantic row. We also need to maintain the
		// original tid for the storage to know which version is frozen.
		mut row2 := new_row(row.data.clone())
		row2.id = row.id
		row2.tid = row.tid

		for clause in stmt.set {
			column_name := clause.column_name
			table_column := table.column(column_name)!
			c.context = Identifier{
				catalog_name: table_column.name.catalog_name
				schema_name:  table_column.name.schema_name
				entity_name:  table.name.entity_name
			}
			c.null_type = table_column.typ
			c.default_value = table_column.default_value
			c.identity = identity_of(table, table_column)

			raw_value := clause.source.compile(mut c)!.run(mut conn, row, params)!

			if table_column.not_null && raw_value.is_null {
				return sqlstate_23502('column ${column_name}')
			}

			// Unlike most comparisons we have to treat NULL like a known value
			// for this particular case because we want NULL to be set in cases
			// where the value wasn't NULL.
			//
			// TODO(elliotchance): This has the side effect that NULL being
			//  replaced with NULL is true, which is unnecessary, even if the
			//  logic is a bit murky.
			check_store_assignment(raw_value, table_column.typ)!
			column_id := '${table_name.id()}.${column_name}'
			cmp := compare(conn, row.data[column_id], raw_value)!
			if cmp != .is_equal {
				did_modify = true
				row2.data[column_id] = cast(mut conn, 'for column ${column_name}', raw_value,
					table_column.typ)!
			}
		}

		// A row that doesn't change isn't written, but it's still counted.
		if did_modify {
			// To be able to write the row back we need to clean the column names.
			before := row.for_storage()
			after := row2.for_storage()
			check_constraints.verify(mut conn, after)!
			changes << [before, after]
		}
	}

	for change in changes {
		mut before := change[0]
		mut after := change[1]
		old << before
		if before.object_key(table)! != after.object_key(table)! {
			catalog.storage.delete_row(table_name.storage_id(), mut before)!
			moved << after
		} else {
			catalog.storage.update_row(mut after, table)!
			updated << after
		}
	}

	for mut row in moved {
		catalog.storage.write_row(mut row, table)!
	}
	updated << moved
	catalog.storage.check_unique_constraints(table, updated)!
	_, time_zone := conn.now()
	catalog.storage.check_foreign_keys(table, updated, time_zone)!
	catalog.storage.check_referencing_rows(table, old, updated, time_zone)!

	// There is a case where no records were updated. The potential problem is
	// that the field assignments might be wrong, but we never knew they were
	// wrong (because we never actually evaluated them for any rows). So if
	// nothing was match, we do a dummy match just to catch errors that would
	// otherwise not be caught.
	//
	// We could do this before the UPDATE to catch the error earlier, but that
	// comes at the cost of evaulating the row when we might not need to.
	if rows.len == 0 {
		// ISO/IEC 9075-2:2016(E), 14.14, General Rules, 15
		conn.add_warning(sqlstate_02000())

		conn.dry_run = true
		defer {
			conn.dry_run = false
		}

		empty_row := new_empty_row(table.columns, table_name.id())
		for clause in stmt.set {
			column_name := clause.column_name
			table_column := table.column(column_name)!
			c.null_type = table_column.typ
			c.default_value = table_column.default_value
			c.identity = identity_of(table, table_column)
			raw_value := clause.source.compile(mut c)!.run(mut conn, empty_row, params)!
			check_store_assignment(raw_value, table_column.typ)!
			value := cast(mut conn, 'for column ${column_name}', raw_value, table_column.typ)!

			if table_column.not_null && value.is_null {
				return sqlstate_23502('column ${column_name}')
			}
		}
	}

	// The count is every row identified by the UPDATE, even if its values didn't
	// change.
	//
	// ISO/IEC 9075-2:2016(E), 23.1, General Rules, f iii
	return new_result_msg('UPDATE ${rows.len}', elapsed_parse, t.elapsed())
}

fn (stmt UpdateStatementSearched) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut plan := create_plan(stmt, params, mut conn)!

	return plan.explain(elapsed_parse)
}
