// join.v contains operations for handing JOIN operations.

module vsql

struct JoinOperation {
	left_columns  Columns
	join_type     string
	right_columns Columns
	specification Expr
	params        map[string]Value
	conn          &Connection
mut:
	plan    Plan
	storage Storage
}

fn new_join_operation(left_columns Columns, join_type string, right_columns Columns, specification Expr, params map[string]Value, conn &Connection, plan Plan, storage Storage) &JoinOperation {
	return &JoinOperation{left_columns, join_type, right_columns, specification, params, conn, plan, storage}
}

fn (o &JoinOperation) str() string {
	return '$o.join_type JOIN ON $o.specification ($o.columns())'
}

fn (o &JoinOperation) columns() Columns {
	mut columns := o.left_columns
	columns << o.right_columns

	return columns
}

fn (mut o JoinOperation) execute(rows []Row) ?[]Row {
	left_rows := o.plan.subplans['\$1'].execute([]Row{})?
	right_rows := o.plan.subplans['\$2'].execute([]Row{})?

	match o.join_type {
		'INNER' {
			return o.execute_inner(left_rows, right_rows)
		}
		'LEFT' {
			return o.execute_left(left_rows, right_rows)
		}
		'RIGHT' {
			return o.execute_right(left_rows, right_rows)
		}
		else {
			// Should not be possible.
			//
			// TODO(elliotchance): Make join_type exhaustive with an enum.
			return []Row{}
		}
	}
}

fn (mut o JoinOperation) execute_inner(left_rows []Row, right_rows []Row) ?[]Row {
	mut new_rows := []Row{}

	for left_row in left_rows {
		for right_row in right_rows {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}
			for k, v in right_row.data {
				row.data[k] = v
			}

			if eval_as_bool(o.conn, row, o.specification, o.params)? {
				new_rows << row
			}
		}
	}

	return new_rows
}

fn (mut o JoinOperation) execute_left(left_rows []Row, right_rows []Row) ?[]Row {
	mut new_rows := []Row{}

	for left_row in left_rows {
		mut matched := false

		for right_row in right_rows {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}

			for k, v in right_row.data {
				row.data[k] = v
			}

			if eval_as_bool(o.conn, row, o.specification, o.params)? {
				new_rows << row
				matched = true
			}
		}

		if !matched {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}

			for k in o.right_columns {
				row.data[k.name] = new_null_value()
			}

			new_rows << row
		}
	}

	return new_rows
}

fn (mut o JoinOperation) execute_right(left_rows []Row, right_rows []Row) ?[]Row {
	mut new_rows := []Row{}

	for right_row in right_rows {
		mut matched := false

		for left_row in left_rows {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}

			for k, v in right_row.data {
				row.data[k] = v
			}

			if eval_as_bool(o.conn, row, o.specification, o.params)? {
				new_rows << row
				matched = true
			}
		}

		if !matched {
			mut row := new_row(map[string]Value{})

			for k in o.left_columns {
				row.data[k.name] = new_null_value()
			}

			for k, v in right_row.data {
				row.data[k] = v
			}

			new_rows << row
		}
	}

	return new_rows
}
