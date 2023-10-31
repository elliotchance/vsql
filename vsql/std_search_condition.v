module vsql

// ISO/IEC 9075-2:2016(E), 8.21, <search condition>
//
// # Function
//
// Specify a condition that is True, False, or Unknown, depending on the value
// of a <boolean value expression>.
//
// # Format
//~
//~ <search condition> /* BooleanValueExpression */ ::=
//~     <boolean value expression>

// A WhereOperation executes a condition on each row, only passing through rows
// that evaluate to TRUE.
struct WhereOperation {
	condition BooleanValueExpression
	params    map[string]Value
	columns   Columns
mut:
	conn &Connection
}

fn new_where_operation(condition BooleanValueExpression, params map[string]Value, conn &Connection, columns Columns) &WhereOperation {
	return &WhereOperation{condition, params, columns, conn}
}

fn (o &WhereOperation) str() string {
	return 'WHERE ${o.condition.pstr(o.params)}'
}

fn (o &WhereOperation) columns() Columns {
	// WHERE does not change the columns so pass through from the last
	// operation.
	return o.columns
}

fn (mut o WhereOperation) execute(rows []Row) ![]Row {
	mut new_rows := []Row{}

	for row in rows {
		mut ok := eval_as_bool(mut o.conn, row, o.condition, o.params)!
		if ok {
			new_rows << row
		}
	}

	return new_rows
}

fn eval_as_bool(mut conn Connection, data Row, e BooleanValueExpression, params map[string]Value) !bool {
	v := e.eval(mut conn, data, params)!

	if v.typ.typ == .is_boolean {
		return v.bool_value() == .is_true
	}

	return sqlstate_42804('in expression', 'BOOLEAN', v.typ.str())
}
