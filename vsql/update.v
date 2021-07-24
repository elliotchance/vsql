// update.v contains the implementation for the UPDATE statement.

module vsql

fn (mut c Connection) update(stmt UpdateStmt) ?Result {
	table_name := identifier_name(stmt.table_name)

	if table_name !in c.storage.tables {
		return sqlstate_42p01(table_name) // table does not exist
	}

	table := c.storage.tables[table_name]

	// check values are appropriate for the table before beginning
	for k, v in stmt.set {
		column_name := identifier_name(k)
		table_column := table.column(column_name) ?
		cast('for column $column_name', v, table_column.typ) ?
	}

	mut delete_rows := []Row{}
	mut new_rows := []Row{}
	for mut row in c.storage.read_rows(table.index) ? {
		// Missing WHERE matches all records
		mut ok := true
		if stmt.where.op != '' {
			ok = eval(row, stmt.where) ?
		}

		if ok {
			mut did_modify := false
			mut new_row := Row{
				data: row.data.clone()
			}
			for k, v in stmt.set {
				column_name := identifier_name(k)
				table_column := table.column(column_name) ?

				if row.data[column_name] != v {
					did_modify = true

					// msg ignored here becuase the type have already been
					// checked above.
					row.data[column_name] = cast('', v, table_column.typ) ?
					new_row.data[column_name] = cast('', v, table_column.typ) ?
				}
			}

			if did_modify {
				delete_rows << row
				new_rows << new_row
			}
		}
	}

	for row in delete_rows {
		c.storage.delete_row(row) ?
	}

	for row in new_rows {
		c.storage.write_row(row, table) ?
	}

	return new_result_msg('UPDATE $new_rows.len')
}
