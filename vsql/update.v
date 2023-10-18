// update.v contains the implementation for the UPDATE statement.
//
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

module vsql

import time

fn execute_update(mut c Connection, stmt UpdateStmt, params map[string]Value, elapsed_parse time.Duration, explain bool) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	mut plan := create_plan(stmt, params, mut c)!

	if explain {
		return plan.explain(elapsed_parse)
	}

	mut rows := plan.execute([]Row{})!
	mut table_name := c.resolve_table_identifier(stmt.table_name, false)!
	table := catalog.storage.tables[table_name.storage_id()]

	mut modify_count := 0
	for mut row in rows {
		mut did_modify := false

		// When creating a new row make sure we also carry across the internal
		// ID. This allows the underlying storage to indentify it as a different
		// version of the same semantic row. We also need to maintain the
		// original tid for the storage to know which version is frozen.
		mut row2 := new_row(row.data.clone())
		row2.id = row.id
		row2.tid = row.tid

		for column_name, v in stmt.set {
			table_column := table.column(column_name)!
			raw_value := eval_as_nullable_value(mut c, table_column.typ.typ, row, resolve_identifiers(c,
				v, catalog.storage.tables)!, params)!

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
			column_id := '${table_name.id()}.${column_name}'
			cmp := compare(row.data[column_id], raw_value)!
			if cmp != .is_equal {
				did_modify = true
				row2.data[column_id] = cast(mut c, 'for column ${column_name}', raw_value,
					table_column.typ)!
			}
		}

		if did_modify {
			// To be able to write the row back we need to clean the column names.
			modify_count++
			catalog.storage.update_row(mut row.for_storage(), mut row2.for_storage(),
				table)!
		}
	}

	// There is a case where no records were updated. The potential problem is
	// that the field assignments might be wrong, but we never knew they were
	// wrong (because we never actually evaluated them for any rows). So if
	// nothing was match, we do a dummy match just to catch errors that would
	// otherwise not be caught.
	//
	// We could do this before the UPDATE to catch the error earlier, but that
	// comes at the cost of evaulating the row when we might not need to.
	if modify_count == 0 {
		empty_row := new_empty_row(table.columns, '')
		for column_name, v in stmt.set {
			table_column := table.column(column_name)!
			raw_value := eval_as_nullable_value(mut c, table_column.typ.typ, empty_row,
				resolve_identifiers(c, v, catalog.storage.tables)!, params)!
			value := cast(mut c, 'for column ${column_name}', raw_value, table_column.typ)!

			if table_column.not_null && value.is_null {
				return sqlstate_23502('column ${column_name}')
			}
		}
	}

	return new_result_msg('UPDATE ${modify_count}', elapsed_parse, t.elapsed())
}
