// result.v contains the implementation of results which is a set of rows that
// can be iterated from a query.

module vsql

import time

// A Result contains zero or more rows returned from a query.
//
// See next() for an example on iterating rows in a Result.
pub struct Result {
	// rows is not public because in the future this may end up being a cursor.
	// You should use V iteration to read the rows.
	rows []Row
pub:
	// The columns provided for each row (even if there are zero rows.)
	columns []Column
	// The time it took to parse/compile the query before running it.
	elapsed_parse time.Duration
	// The time is took to execute the query.
	elapsed_exec time.Duration
	// msg is the status of a statement that doesn't return rows, such as
	// "CREATE TABLE 1" or "INSERT 3". It is empty for a query, and a statement
	// with a msg has no columns or rows.
	msg string
mut:
	idx int
}

pub fn new_result(columns Columns, rows []Row, elapsed_parse time.Duration, elapsed_exec time.Duration) Result {
	return Result{
		columns:       columns
		rows:          rows
		elapsed_parse: elapsed_parse
		elapsed_exec:  elapsed_exec
	}
}

fn new_result_msg(msg string, elapsed_parse time.Duration, elapsed_exec time.Duration) Result {
	return Result{
		msg:           msg
		elapsed_parse: elapsed_parse
		elapsed_exec:  elapsed_exec
	}
}

// next provides the iteration for V, use it like:
//
//   for row in result { }
pub fn (mut r Result) next() ?Row {
	if r.idx >= r.rows.len {
		return none
	}
	defer {
		r.idx++
	}

	return r.rows[r.idx]
}
