// where.v executes expressions on a multiple rows.

module vsql

fn where(conn Connection, rows []Row, inverse bool, expr Expr) ?[]Row {
	mut new_rows := []Row{}
	for row in rows {
		mut ok := eval_as_bool(conn, row, expr) ?
		if inverse {
			ok = !ok
		}
		if ok {
			new_rows << row
		}
	}

	return new_rows
}
