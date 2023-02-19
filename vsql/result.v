// result.v contains the implementation of results which is a set of rows that
// can be iterated from a query.

module vsql

import time

// A Result contains zero or more rows returned from a query.
//
// See next() for an example on iterating rows in a Result.
//
// snippet: v.Result
pub struct Result {
	// rows is not public because in the future this may end up being a cursor.
	// You should use V iteration to read the rows.
	rows []Row
pub:
	// The columns provided for each row (even if there are zero rows.)
	//
	// snippet: v.Result.columns
	columns []Column
	// The time it took to parse/compile the query before running it.
	//
	// snippet: v.Result.elapsed_parse
	elapsed_parse time.Duration
	// The time is took to execute the query.
	//
	// snippet: v.Result.elapsed_exec
	elapsed_exec time.Duration
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
	return new_result([
		Column{Identifier{ sub_entity_name: 'msg' }, new_type('VARCHAR', 0), false},
	], [
		Row{
			data: {
				'msg': new_varchar_value(msg, 0)
			}
		},
	], elapsed_parse, elapsed_exec)
}

// next provides the iteration for V, use it like:
//
//   for row in result { }
//
// snippet: v.Result.next
pub fn (mut r Result) next() ?Row {
	if r.idx >= r.rows.len {
		return none
	}
	defer {
		r.idx++
	}

	return r.rows[r.idx]
}
