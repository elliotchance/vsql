// update.v contains the implementation for the UPDATE statement.

module vsql

import time

fn execute_update(mut c Connection, stmt UpdateStmt, params map[string]Value, elapsed_parse time.Duration, explain bool) ?Result {
	t := start_timer()

	c.open_write_connection() ?
	defer {
		c.release_connection()
	}

	plan := create_plan(stmt, params, c) ?

	if explain {
		return plan.explain(elapsed_parse)
	}

	mut rows := plan.execute([]Row{}) ?

	table_name := identifier_name(stmt.table_name)
	table := c.storage.tables[table_name]

	// check values are appropriate for the table before beginning
	empty_row := new_empty_row(table.columns)
	for k, v in stmt.set {
		column_name := identifier_name(k)
		table_column := table.column(column_name) ?
		raw_value := eval_as_value(c, empty_row, v, params) ?
		value := cast('for column $column_name', raw_value, table_column.typ) ?

		if table_column.not_null && value.typ.typ == .is_null {
			return sqlstate_23502('column $column_name')
		}
	}

	mut delete_rows := []Row{}
	mut new_rows := []Row{}
	for mut row in rows {
		mut did_modify := false
		mut row2 := new_row(row.data.clone())
		for k, v in stmt.set {
			column_name := identifier_name(k)
			table_column := table.column(column_name) ?
			raw_value := eval_as_value(c, row, v, params) ?

			if row.data[column_name] != raw_value {
				did_modify = true

				// msg ignored here becuase the type have already been
				// checked above.
				row2.data[column_name] = cast('', raw_value, table_column.typ) ?
			}
		}

		if did_modify {
			delete_rows << row
			new_rows << row2
		}
	}

	for mut row in delete_rows {
		c.storage.delete_row(table_name, mut row) ?
	}

	for mut row in new_rows {
		c.storage.write_row(mut row, table) ?
	}

	return new_result_msg('UPDATE $new_rows.len', elapsed_parse, t.elapsed())
}
