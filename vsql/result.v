// result.v contains the implementation of results which is a set of rows that
// can be iterated from a query.

module vsql

import time

struct Result {
pub:
	columns       []Column
	rows          []Row
	elapsed_parse time.Duration
	elapsed_exec  time.Duration
mut:
	idx int
}

pub fn new_result(columns Columns, rows []Row, elapsed_parse time.Duration, elapsed_exec time.Duration) Result {
	return Result{
		columns: columns
		rows: rows
		elapsed_parse: elapsed_parse
		elapsed_exec: elapsed_exec
	}
}

fn new_result_msg(msg string, elapsed_parse time.Duration, elapsed_exec time.Duration) Result {
	return new_result([Column{'msg', new_type('VARCHAR', 0, 0), false}], [
		Row{
			data: {
				'msg': new_varchar_value(msg, 0)
			}
		},
	], elapsed_parse, elapsed_exec)
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
