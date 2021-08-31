// insert.v contains the implementation for the INSERT statement.

module vsql

fn (mut c Connection) insert(stmt InsertStmt) ?Result {
	mut row := Row{
		data: map[string]Value{}
	}

	if stmt.columns.len < stmt.values.len {
		return sqlstate_42601('INSERT has more values than columns')
	}

	if stmt.columns.len > stmt.values.len {
		return sqlstate_42601('INSERT has less values than columns')
	}

	table_name := identifier_name(stmt.table_name)
	if table_name !in c.storage.tables {
		return sqlstate_42p01(table_name) // table not found
	}

	table := c.storage.tables[table_name]
	for i, column in stmt.columns {
		column_name := identifier_name(column.name)
		table_column := table.column(column_name) ?
		raw_value := eval_as_value(c, Row{}, stmt.values[i]) ?
		value := cast('for column $column_name', raw_value, table_column.typ) ?

		if value.typ.typ == .is_null && table_column.not_null {
			return sqlstate_23502('column $column_name')
		}

		row.data[column_name] = value
	}

	// Fill in unspecified columns with NULL
	for col in table.columns {
		if col.name in row.data {
			continue
		}

		if col.not_null {
			return sqlstate_23502('column $col.name')
		}

		row.data[col.name] = new_null_value()
	}

	c.storage.write_row(row, table) ?

	return new_result_msg('INSERT 1')
}
