// key_order.v avoids sorting the rows for an ORDER BY when they're already read
// in that order, by the PRIMARY KEY or an index.

module vsql

// A KeyOrderColumn is a column of a key (the PRIMARY KEY or an index), in the
// order that the rows are read in.
struct KeyOrderColumn {
	name string
	desc bool
}

// use_key_order is true when the rows of plan are already in the order of the
// sort keys, so they don't need to be sorted. A table that would be read in
// full is read through an index instead when that gives the order. The rows are
// read in the order of a key when every sort key is a column of the table, in
// the same order as the columns of the key, and the same direction (a PRIMARY
// KEY is always ASC). A column of the key that's compared with = in the WHERE
// clause has the same value in every row, so it can be skipped, or be a sort key
// in either direction.
//
// A NULL is in the same place in an index as in an ORDER BY (first for ASC and
// last for DESC). Rows that are equal for every sort key (peers) are in an
// implementation-dependent order, which is the order of the rest of the key (and
// then the row).
//
// ISO/IEC 9075-2:2016(E), 10.10, <sort specification list>, General Rules, 1
fn use_key_order(mut plan Plan, order []SortSpecification, result_columns map[string][]ValueExpression, params map[string]Value, mut conn Connection) bool {
	// Only the rows of one table are read, and they're still the rows of the
	// table (not groups) when they're sorted. A query specification always has
	// an operation that reads its rows.
	for operation in plan.operations[1..] {
		if operation !is WhereOperation && operation !is DistinctOperation {
			return false
		}
	}

	mut operation := plan.operations[0]
	mut table := Table{}
	mut key := ?&KeyOperation(none)
	if mut operation is TableOperation {
		if operation.table_is_subplan {
			return false
		}
		table = operation.table
	} else if mut operation is KeyOperation {
		table = operation.table
		key = operation
	} else {
		return false
	}

	mut columns := []string{}
	for spec in order {
		columns << sort_key_column(spec, table, result_columns, conn) or { return false }
	}

	if k := key {
		return is_key_order(order, columns, k.order_columns(), k.equal_columns())
	}

	if is_key_order(order, columns, table.primary_key.map(KeyOrderColumn{it, false}),
		[]int{})
	{
		return true
	}

	catalog := conn.catalog_for(table.name)
	for index in catalog.storage.table_indexes(table.id) {
		if is_key_order(order, columns, index.columns.map(KeyOrderColumn{it.name, it.desc}),
			[]int{})
		{
			plan.operations[0] = new_index_operation(table, index, [], params, conn)
			return true
		}
	}

	return false
}

// sort_key_column is the name of the column of table that the sort key is, if
// it's only a column reference. A name that's a column of the result is that
// column's expression (see set_result_columns). The name can't be ambiguous,
// that's already an error when the sort key is compiled.
fn sort_key_column(spec SortSpecification, table Table, result_columns map[string][]ValueExpression, conn &Connection) ?string {
	mut column := value_column_reference(spec.expr)?
	if column.entity_name == '' && column.custom_id == '' {
		if exprs := result_columns[column.sub_entity_name] {
			column = value_column_reference(exprs[0])?
		}
	}

	if column.custom_id != '' || !column.is_column_of_table(conn, table) {
		return none
	}

	return column.sub_entity_name
}

// value_column_reference is the column if the expression is only a column
// reference, such as "a" or "t.a". A column reference is parsed as a
// BooleanValueExpression, and each column of "SELECT *" is a DatetimePrimary
// (see new_expr_operation).
fn value_column_reference(expr ValueExpression) ?Identifier {
	if expr is CommonValueExpression {
		common := CommonValueExpression(expr)
		if common is DatetimePrimary {
			datetime := DatetimePrimary(common)
			if datetime is ValueExpressionPrimary {
				primary := ValueExpressionPrimary(datetime)
				if primary is NonparenthesizedValueExpressionPrimary {
					nonparenthesized := NonparenthesizedValueExpressionPrimary(primary)
					if nonparenthesized is &Identifier {
						return *nonparenthesized
					}
				}
			}
		}

		return none
	}

	return DerivedColumn{
		expr: expr
	}.column_reference()
}

// is_key_order is true when the rows in the order of the key_columns are also
// in the order of the sort keys, which are the columns. equal_columns are the
// positions of the key_columns that have the same value in every row.
fn is_key_order(order []SortSpecification, columns []string, key_columns []KeyOrderColumn, equal_columns []int) bool {
	if key_columns.len == 0 {
		return false
	}

	mut next := 0
	for i, spec in order {
		mut is_equal := false
		for j in equal_columns {
			if key_columns[j].name == columns[i] {
				is_equal = true
			}
		}
		if is_equal {
			continue
		}

		for next < key_columns.len && next in equal_columns {
			next++
		}
		if next >= key_columns.len || key_columns[next].name != columns[i]
			|| key_columns[next].desc == spec.is_asc {
			return false
		}
		next++
	}

	return true
}

// order_columns are the columns of the key, in the order that the rows are read
// in.
fn (o &KeyOperation) order_columns() []KeyOrderColumn {
	if index := o.index {
		return index.columns.map(KeyOrderColumn{it.name, it.desc})
	}

	return o.table.primary_key.map(KeyOrderColumn{it, false})
}

// equal_columns are the positions of the columns of the key that are compared
// with = in the WHERE clause, so every row has the same value for them.
fn (o &KeyOperation) equal_columns() []int {
	mut columns := []int{}
	for condition in o.conditions {
		if condition.op == .equal {
			columns << condition.column
		}
	}

	return columns
}
