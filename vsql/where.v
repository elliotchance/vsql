// where.v executes expressions on a multiple rows.

module vsql

// A WhereOperation executes a condition on each row, only passing through rows
// that evaluate to TRUE.
struct WhereOperation {
	condition Expr
	params    map[string]Value
	conn      &Connection
	columns   Columns
}

fn new_where_operation(condition Expr, params map[string]Value, conn &Connection, columns Columns) &WhereOperation {
	return &WhereOperation{condition, params, conn, columns}
}

fn (o &WhereOperation) str() string {
	return 'WHERE ${o.condition.pstr(o.params)}'
}

fn (o &WhereOperation) columns() Columns {
	// WHERE does not change the columns so pass through from the last
	// operation.
	return o.columns
}

fn (o &WhereOperation) execute(rows []Row) ?[]Row {
	mut new_rows := []Row{}

	for row in rows {
		mut ok := eval_as_bool(o.conn, row, o.condition, o.params) ?
		if ok {
			new_rows << row
		}
	}

	return new_rows
}
