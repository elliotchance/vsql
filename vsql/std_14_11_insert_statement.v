module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>
//
// Create new rows in a table.

struct InsertStatement {
	table_name Identifier
	columns    []Identifier
	values     []ContextuallyTypedRowValueConstructor
}

fn (stmt InsertStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut insert_columns := map[string]bool{}
	for column in stmt.columns {
		if column.sub_entity_name in insert_columns {
			return sqlstate_42601('column ${column.sub_entity_name} is specified more than once')
		}
		insert_columns[column.sub_entity_name] = true
	}

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	table := catalog.storage.tables[table_name.storage_id()]

	// Each element of the VALUES is a row. All of the rows are checked before
	// any of them are written, so that an error in one row doesn't leave the
	// rows before it in the table.
	mut rows := []Row{}
	for row_value in stmt.values {
		rows << new_row(stmt.insert_row(mut conn, params, table, row_value)!)
	}

	for mut row in rows {
		catalog.storage.write_row(mut row, table)!
	}

	return new_result_msg('INSERT ${rows.len}', elapsed_parse, t.elapsed())
}

// insert_row returns the values for a new row from one row of the VALUES. A
// row with more than one value is in parentheses, otherwise the row has one
// value.
fn (stmt InsertStatement) insert_row(mut conn Connection, params map[string]Value, table Table, row_value ContextuallyTypedRowValueConstructor) !map[string]Value {
	mut values := []ContextuallyTypedRowValueConstructor{}
	if row_value is []ContextuallyTypedRowValueConstructorElement {
		for v in row_value {
			match v {
				ValueExpression {
					match v {
						CommonValueExpression {
							values << ContextuallyTypedRowValueConstructor(v)
						}
						BooleanValueExpression {
							values << ContextuallyTypedRowValueConstructor(v)
						}
					}
				}
				NullSpecification {
					values << ContextuallyTypedRowValueConstructor(v)
				}
			}
		}
	} else {
		values << row_value
	}

	if stmt.columns.len < values.len {
		return sqlstate_42601('INSERT has more values than columns')
	}

	if stmt.columns.len > values.len {
		return sqlstate_42601('INSERT has less values than columns')
	}

	mut row := map[string]Value{}
	for i, column in stmt.columns {
		column_name := column.sub_entity_name
		table_column := table.column(column_name)!

		mut c := Compiler{
			conn:      conn
			params:    params
			null_type: table_column.typ
		}
		raw_value := values[i].compile(mut c)!.run(mut conn, Row{}, params)!

		value := cast(mut conn, 'for column ${column_name}', raw_value, table_column.typ)!

		if value.is_null && table_column.not_null {
			return sqlstate_23502('column ${column_name}')
		}

		row[column_name] = value
	}

	// Fill in unspecified columns with NULL
	for col in table.columns {
		if col.name.sub_entity_name in row {
			continue
		}

		if col.not_null {
			return sqlstate_23502('column ${col.name}')
		}

		row[col.name.sub_entity_name] = new_null_value(col.typ.typ)
	}

	return row
}

fn (stmt InsertStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN INSERT')
}
