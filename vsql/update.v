// update.v contains the implementation for the UPDATE statement.

module vsql

fn (mut c Connection) update(stmt UpdateStmt) ?Result {
	if stmt.table_name !in c.storage.tables {
		return sqlstate_42p01(stmt.table_name) // table does not exist
	}

	table := c.storage.tables[stmt.table_name]

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
				if row.data[k] != v {
					did_modify = true
					row.data[k] = v
					new_row.data[k] = v
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
