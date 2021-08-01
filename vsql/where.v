// where.v executes expressions on a multiple rows.

module vsql

// fetch: -1 to ignore, otherwise the max records to return.
fn where(conn Connection, rows []Row, inverse bool, expr Expr, fetch int) ?[]Row {
	mut new_rows := []Row{}
	for row in rows {
		mut ok := eval_as_bool(conn, row, expr) ?
		if inverse {
			ok = !ok
		}
		if ok {
			new_rows << row
		}
		if fetch >= 0 && new_rows.len == fetch {
			break
		}
	}

	return new_rows
}
