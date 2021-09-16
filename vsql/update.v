// update.v contains the implementation for the UPDATE statement.

module vsql

import time

fn execute_update(mut c Connection, stmt UpdateStmt, params map[string]Value, elapsed_parse time.Duration) ?Result {
	t := start_timer()

	table_name := identifier_name(stmt.table_name)

	if table_name !in c.storage.tables {
		return sqlstate_42p01(table_name) // table does not exist
	}

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
	for mut row in c.storage.read_rows(table.name, 0) ? {
		// Missing WHERE matches all records
		mut ok := true
		if stmt.where !is NoExpr {
			ok = eval_as_bool(c, row, stmt.where, params) ?
		}

		if ok {
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
					row.data[column_name] = cast('', raw_value, table_column.typ) ?
					row2.data[column_name] = cast('', raw_value, table_column.typ) ?
				}
			}

			if did_modify {
				delete_rows << row
				new_rows << row2
			}
		}
	}

	for row in delete_rows {
		c.storage.delete_row(table.name, row) ?
	}

	for row in new_rows {
		c.storage.write_row(row, table) ?
	}

	return new_result_msg('UPDATE $new_rows.len', elapsed_parse, t.elapsed())
}
