module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>
//
// # Function
//
// Create new rows in a table.
//
// # Format
//~
//~ <insert statement> /* Stmt */ ::=
//~     INSERT INTO
//~     <insertion target>
//~     <insert columns and source>   -> insert_statement
//~
//~ <insertion target> /* Identifier */ ::=
//~     <table name>
//~
//~ <insert columns and source> /* InsertStatement */ ::=
//~   <from constructor>
//~
//~ <from constructor> /* InsertStatement */ ::=
//~     <left paren> <insert column list> <right paren>
//~     <contextually typed table value constructor>   -> from_constructor
//~
//~ <insert column list> /* []Identifier */ ::=
//~     <column name list>

struct InsertStatement {
	table_name Identifier
	columns    []Identifier
	values     []ContextuallyTypedRowValueConstructor
}

fn parse_insert_statement(insertion_target Identifier, stmt InsertStatement) !Stmt {
	return InsertStatement{insertion_target, stmt.columns, stmt.values}
}

fn parse_from_constructor(columns []Identifier, values []ContextuallyTypedRowValueConstructor) !InsertStatement {
	return InsertStatement{
		columns: columns
		values: values
	}
}

fn (stmt InsertStatement) execute(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
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

fn (stmt InsertStatement) explain(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN INSERT')
}

// eval_as_nullable_value is a broader version of eval_as_value that also takes
// the known destination type as so allows for untyped NULLs.
//
// TODO(elliotchance): Is this even needed? Can eval_as_value be refactored to
//  work the same way and avoid this extra layer?
fn eval_as_nullable_value(mut conn Connection, typ SQLType, data Row, e ContextuallyTypedRowValueConstructor, params map[string]Value) !Value {
	if e is NullSpecification {
		return new_null_value(typ)
	}

	return e.eval(mut conn, data, params)
}
