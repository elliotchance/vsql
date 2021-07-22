// where.v executes expressions on a multiple rows.

module vdb

fn where(rows []Row, inverse bool, expr BinaryExpr) ?[]Row {
	mut new_rows := []Row{}
	for row in rows {
		mut ok := eval(row, expr) ?
		if inverse {
			ok = !ok
		}
		if ok {
			new_rows << row
		}
	}

	return new_rows
}
