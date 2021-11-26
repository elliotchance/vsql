// limit.v contains operations for handing limits and offsets.

module vsql

// A LimitOperation stops after a specified number of rows have been received.
struct LimitOperation {
	fetch   Expr
	params  map[string]Value
	conn    &Connection
	columns Columns
}

fn new_limit_operation(fetch Expr, params map[string]Value, conn &Connection, columns Columns) &LimitOperation {
	return &LimitOperation{fetch, params, conn, columns}
}

fn (o &LimitOperation) str() string {
	return 'FETCH FIRST ${o.fetch.pstr(o.params)} ROWS ONLY'
}

fn (o &LimitOperation) columns() Columns {
	// Limit doesn't change the columns so just pass through from the last
	// operation.
	return o.columns
}

fn (o &LimitOperation) execute(rows []Row) ?[]Row {
	mut fetch := int((eval_as_value(o.conn, Row{}, o.fetch, o.params) ?).f64_value)

	if fetch < rows.len {
		return rows[..fetch]
	}

	return rows
}
