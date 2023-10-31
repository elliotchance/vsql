// insert.v contains the implementation for the INSERT statement.

module vsql

import time

fn execute_insert(mut c Connection, stmt InsertStatement, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	mut row := map[string]Value{}
	mut table_name := c.resolve_table_identifier(stmt.table_name, false)!

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
		raw_value := eval_as_nullable_value(mut c, table_column.typ.typ, Row{}, values[i].resolve_identifiers(c,
			catalog.storage.tables)!, params)!
		value := cast(mut c, 'for column ${column_name}', raw_value, table_column.typ)!

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
