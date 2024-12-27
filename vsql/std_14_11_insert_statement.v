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

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	mut row := map[string]Value{}
	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!

	mut values := stmt.values.clone()
	first_value := stmt.values[0]
	if first_value is []ContextuallyTypedRowValueConstructorElement {
		mut new_values := []ContextuallyTypedRowValueConstructor{}
		for v in first_value {
			match v {
				ValueExpression {
					match v {
						CommonValueExpression {
							new_values << ContextuallyTypedRowValueConstructor(v)
						}
						BooleanValueExpression {
							new_values << ContextuallyTypedRowValueConstructor(v)
						}
					}
				}
				NullSpecification {
					new_values << ContextuallyTypedRowValueConstructor(v)
				}
			}
		}

		values = new_values.clone()
	}

	if stmt.columns.len < values.len {
		return sqlstate_42601('INSERT has more values than columns')
	}

	if stmt.columns.len > values.len {
		return sqlstate_42601('INSERT has less values than columns')
	}

	table := catalog.storage.tables[table_name.storage_id()]
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

	catalog.storage.write_row(mut new_row(row), table)!

	return new_result_msg('INSERT 1', elapsed_parse, t.elapsed())
}

fn (stmt InsertStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN INSERT')
}
