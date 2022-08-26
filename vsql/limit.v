// limit.v contains operations for handing limits and offsets.

module vsql

// A LimitOperation stops after a specified number of rows have been received.
// It is also used for OFFSET clauses.
struct LimitOperation {
	fetch   Expr // may be NoExpr
	offset  Expr // may be NoExpr
	params  map[string]Value
	conn    &Connection
	columns Columns
}

fn new_limit_operation(fetch Expr, offset Expr, params map[string]Value, conn &Connection, columns Columns) &LimitOperation {
	return &LimitOperation{fetch, offset, params, conn, columns}
}

fn (o &LimitOperation) str() string {
	mut s := ''

	if o.offset !is NoExpr {
		s = 'OFFSET ${o.offset.pstr(o.params)} ROWS'
	}

	if o.fetch !is NoExpr {
		s += ' FETCH FIRST ${o.fetch.pstr(o.params)} ROWS ONLY'
	}

	return s.trim_space()
}

fn (o &LimitOperation) columns() Columns {
	// Limit doesn't change the columns so just pass through from the last
	// operation.
	return o.columns
}

fn (o &LimitOperation) execute(rows []Row) ![]Row {
	mut offset := i64(0)
	if o.offset !is NoExpr {
		offset = (eval_as_value(o.conn, Row{}, o.offset, o.params)!).as_int()

		if offset >= rows.len {
			return []Row{}
		}
	}

	mut fetch := i64(rows.len)
	if o.fetch !is NoExpr {
		fetch = (eval_as_value(o.conn, Row{}, o.fetch, o.params)!).as_int()
	}

	if offset + fetch >= rows.len {
		fetch = rows.len - offset
	}

	return rows[offset..offset + fetch]
}
