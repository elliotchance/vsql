module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>
//
// Create new rows in a table.
//
// The concepts are described by:
//
// ISO/IEC 9075-2:2016(E), 4.15.6, Table updatability
// ISO/IEC 9075-2:2016(E), 4.15.10, Operations involving tables

// overriding is the <override clause>, which is 'USER' (OVERRIDING USER
// VALUE), 'SYSTEM' (OVERRIDING SYSTEM VALUE), or empty when it's not given. The
// rows are either values (a <from constructor>) or query (a <from subquery>).
// columns is empty when there's no <insert column list>.
struct InsertStatement {
	table_name Identifier
	columns    []Identifier
	overriding string
	values     []ContextuallyTypedRowValueConstructor
	query      ?QueryExpression
}

fn (stmt InsertStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// No column can be listed more than once.
	//
	// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 8
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

	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())

	// Without an <insert column list>, it's every column in the order of the
	// table.
	//
	// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 7
	columns := if stmt.columns.len > 0 { stmt.columns } else { table.columns.map(it.name) }
	stmt.check_override_clause(table, columns)!

	// Each element of the VALUES is a row, and so is each row of a query. All
	// of the rows are checked before any of them are written, so that an error
	// in one row doesn't leave the rows before it in the table. For the same
	// reason, a query that reads from the table doesn't see the new rows. A
	// generated column is set from the other columns of its row.
	//
	// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 5, 6, 7 and 8.a
	// ISO/IEC 9075-2:2016(E), 15.10, Effect of inserting tables into base tables, General Rules, 5.a and 5.c
	check_constraints := new_check_constraints(mut conn, table)!
	generated_columns := new_generated_columns(mut conn, table)!
	row_values := if query := stmt.query {
		stmt.query_rows(mut conn, params, table, columns, query)!
	} else {
		stmt.values.map(row_elements(it))
	}
	mut rows := []Row{}
	for values in row_values {
		conn.begin_row()
		mut row := new_row(stmt.insert_row(mut conn, params, table, columns, values)!)
		generated_columns.apply(mut conn, mut row)!
		check_constraints.verify(mut conn, row)!
		rows << row
	}

	for mut row in rows {
		catalog.storage.write_row(mut row, table)!
	}
	catalog.storage.check_unique_indexes(table, rows)!
	catalog.storage.check_unique_constraints(table, rows)!
	catalog.storage.check_foreign_keys(mut conn, table, rows)!

	// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 9
	if rows.len == 0 {
		conn.add_warning(sqlstate_02000())
	}

	return new_result_msg('INSERT ${rows.len}', elapsed_parse, t.elapsed())
}

// row_elements returns each value of one row of the VALUES. A row with more than
// one value is in parentheses, otherwise the row has one value.
fn row_elements(row_value ContextuallyTypedRowValueConstructor) []ContextuallyTypedRowValueConstructorElement {
	return match row_value {
		[]ContextuallyTypedRowValueConstructorElement {
			row_value
		}
		CommonValueExpression {
			[ContextuallyTypedRowValueConstructorElement(ValueExpression(row_value))]
		}
		BooleanValueExpression {
			[ContextuallyTypedRowValueConstructorElement(ValueExpression(row_value))]
		}
		ContextuallyTypedValueSpecification {
			[ContextuallyTypedRowValueConstructorElement(row_value)]
		}
	}
}

// row_value_constructors returns the rows of a VALUES that turned out to be the
// start of a query (see insert_query). Only a <from constructor> can contain a
// NULL or DEFAULT on its own, because they get their type from the column.
//
// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>, Format
fn row_value_constructors(rows []ContextuallyTypedRowValueConstructor) ![]RowValueConstructor {
	mut constructors := []RowValueConstructor{}
	for row in rows {
		match row {
			CommonValueExpression, BooleanValueExpression {
				constructors << RowValueConstructor(row)
			}
			ContextuallyTypedValueSpecification, []ContextuallyTypedRowValueConstructorElement {
				mut exprs := []ValueExpression{}
				for element in row_elements(row) {
					if element is ValueExpression {
						exprs << element
					} else {
						return sqlstate_42601('NULL and DEFAULT cannot be used in the VALUES of a query')
					}
				}
				constructors << RowValueConstructor(ExplicitRowValueConstructor{exprs})
			}
		}
	}

	return constructors
}

// query_rows returns the values for each new row from the result of a query. The
// query is checked against the columns first, so these errors don't depend on
// the query having any rows. A GENERATED ALWAYS identity column can only be
// assigned from a query with an <override clause>.
//
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 11.b.i, 13 and 14
fn (stmt InsertStatement) query_rows(mut conn Connection, params map[string]Value, table Table, columns []Identifier, query QueryExpression) ![][]ContextuallyTypedRowValueConstructorElement {
	mut plan := create_plan(query, params, mut conn)!
	query_columns := plan.columns()
	check_insert_degree(columns.len, query_columns.len)!

	for i, column in columns {
		table_column := table.column(column.sub_entity_name)!
		if identity := table_column.identity {
			if identity.always && stmt.overriding == '' {
				return sqlstate_428c9(column.sub_entity_name)
			}
		}

		check_assignable(query_columns[i].typ, table_column.typ)!
	}

	mut rows := [][]ContextuallyTypedRowValueConstructorElement{}
	for row in plan.execute([]Row{})! {
		mut values := []ContextuallyTypedRowValueConstructorElement{}
		for column in query_columns {
			values << query_value(row.get_column(column)!)
		}
		rows << values
	}

	return rows
}

// query_value returns a value from the result of a query as a value of a row. A
// null value takes the type of the column, like a NULL in VALUES.
fn query_value(value Value) ContextuallyTypedRowValueConstructorElement {
	if value.is_null {
		return ContextuallyTypedValueSpecification(NullSpecification{})
	}

	return ValueExpression(CommonValueExpression(DatetimePrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(value))))))
}

// check_insert_degree returns an error if a row doesn't have one value for each
// column.
//
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 13
fn check_insert_degree(columns int, values int) ! {
	if columns < values {
		return sqlstate_42601('INSERT has more values than columns')
	}

	if columns > values {
		return sqlstate_42601('INSERT has less values than columns')
	}
}

// insert_row returns the values for a new row from one row of the source.
fn (stmt InsertStatement) insert_row(mut conn Connection, params map[string]Value, table Table, columns []Identifier, values []ContextuallyTypedRowValueConstructorElement) !map[string]Value {
	// Each row must have a value for each column, so they all have the same
	// degree.
	//
	// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>, Syntax Rules, 2
	check_insert_degree(columns.len, values.len)!

	mut row := map[string]Value{}
	for i, column in columns {
		table_column := table.column(column.sub_entity_name)!

		// The value of a generated column must be DEFAULT in VALUES. It can be
		// anything in a query (it only has to be assignable), but the value
		// isn't used. In both cases, it's set once the other columns are known
		// (see GeneratedColumns.apply).
		//
		// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 10
		// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 7.c
		// ISO/IEC 9075-2:2016(E), 11.5, <default clause>, General Rules, 3.a
		if table_column.generated != none {
			if stmt.query == none && !is_default_specification(values[i]) {
				return sqlstate_428c9(column.sub_entity_name)
			}
			continue
		}

		// The value of a GENERATED ALWAYS identity column must be DEFAULT,
		// unless there's an <override clause>. OVERRIDING USER VALUE ignores the
		// value, so the column gets the next value (4.15.12).
		//
		// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 11.b
		// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 7.e
		// ISO/IEC 9075-2:2016(E), 15.10, Effect of inserting tables into base tables, General Rules, 2.a
		mut value := values[i]
		if identity := table_column.identity {
			if identity.always && stmt.overriding == '' && !is_default_specification(value) {
				return sqlstate_428c9(column.sub_entity_name)
			}
			if stmt.overriding == 'USER' {
				value = ContextuallyTypedValueSpecification(DefaultSpecification{})
			}
		}

		row[column.sub_entity_name] = insert_value(mut conn, params, table, table_column,
			value)!
	}

	// A column that isn't listed gets its default.
	//
	// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 7.a
	for col in table.columns {
		if col.name.sub_entity_name !in row && col.generated == none {
			row[col.name.sub_entity_name] = insert_value(mut conn, params, table, col,
				ContextuallyTypedValueSpecification(DefaultSpecification{}))!
		}
	}

	return row
}

// check_override_clause returns an error if the <override clause> can't be used
// for the columns of the INSERT. It can only be used when one of the columns is
// the identity column, and only OVERRIDING USER VALUE can be used for a
// GENERATED BY DEFAULT identity column.
//
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 11.c and 11.e
fn (stmt InsertStatement) check_override_clause(table Table, columns []Identifier) ! {
	if stmt.overriding == '' {
		return
	}

	column := table.identity_column() or {
		return sqlstate_42601('OVERRIDING ${stmt.overriding} VALUE cannot be used without an identity column')
	}
	identity := column.identity or { IdentityColumn{} }
	if !columns.any(it.sub_entity_name == column.name.sub_entity_name) {
		return sqlstate_42601('OVERRIDING ${stmt.overriding} VALUE cannot be used without an identity column')
	}

	if !identity.always && stmt.overriding == 'SYSTEM' {
		return sqlstate_42601('OVERRIDING SYSTEM VALUE cannot be used for identity column ${column.name.sub_entity_name}, which is GENERATED BY DEFAULT')
	}
}

// insert_value returns the value to store in a column of the table, which may
// be DEFAULT. Its type is the type of the column.
//
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 12 and 14
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 7.c
fn insert_value(mut conn Connection, params map[string]Value, table Table, column Column, element ContextuallyTypedRowValueConstructorElement) !Value {
	column_name := column.name.sub_entity_name
	mut c := Compiler{
		conn:          conn
		params:        params
		null_type:     column.typ
		default_value: column.default_value
		identity:      identity_of(table, column)
	}

	// There's no query for an aggregate function to be calculated by.
	//
	// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 7
	compiled := element.compile(mut c)!
	if compiled.contains_agg {
		return sqlstate_42601('an aggregate function cannot be used in VALUES')
	}

	raw_value := compiled.run(mut conn, Row{}, params)!

	check_store_assignment(raw_value, column.typ)!
	value := cast(mut conn, 'for column ${column_name}', raw_value, column.typ)!

	if value.is_null && column.not_null {
		return sqlstate_23502(table, column_name)
	}

	return value
}

fn (stmt InsertStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN INSERT')
}
