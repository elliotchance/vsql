// result.v contains the implementation of results which is a set of rows that
// can be iterated from a query.

module vsql

struct Result {
pub:
	columns []string
	rows    []Row
mut:
	idx int
}

pub fn new_result(columns []string, rows []Row) Result {
	return Result{
		columns: columns
		rows: rows
	}
}

fn new_result_msg(msg string) Result {
	return new_result(['msg'], [
		Row{
			data: {
				'msg': new_varchar_value(msg, 0)
			}
		},
	])
}

pub fn (mut r Result) next() ?Row {
	if r.idx >= r.rows.len {
		return error('')
	}
	defer {
		r.idx++
	}
	return r.rows[r.idx]
}
