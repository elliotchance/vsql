// limit.v contains operations for handing limits and offsets.

module vsql

// A LimitOperation stops after a specified number of rows have been received.
// It is also used for OFFSET clauses.
struct LimitOperation {
	fetch   ?ValueSpecification
	offset  ?ValueSpecification
	params  map[string]Value
	columns Columns
mut:
	conn &Connection
}

fn new_limit_operation(fetch ?ValueSpecification, offset ?ValueSpecification, params map[string]Value, mut conn Connection, columns Columns) &LimitOperation {
	return &LimitOperation{fetch, offset, params, columns, conn}
}

fn (o &LimitOperation) str() string {
	mut s := ''

	if offset := o.offset {
		s = 'OFFSET ${offset.pstr(o.params)} ROWS'
	}

	if fetch := o.fetch {
		s += ' FETCH FIRST ${fetch.pstr(o.params)} ROWS ONLY'
	}

	return s.trim_space()
}

fn (o &LimitOperation) columns() Columns {
	// Limit doesn't change the columns so just pass through from the last
	// operation.
	return o.columns
}

fn (mut o LimitOperation) execute(rows []Row) ![]Row {
	mut offset := i64(0)
	if off := o.offset {
		offset = (off.eval(mut o.conn, Row{}, o.params)!).as_int()

		if offset >= rows.len {
			return []Row{}
		}
	}

	mut fetch := i64(rows.len)
	if f := o.fetch {
		fetch = (f.eval(mut o.conn, Row{}, o.params)!).as_int()
	}

	if offset + fetch >= rows.len {
		fetch = rows.len - offset
	}

	return rows[offset..offset + fetch]
}
