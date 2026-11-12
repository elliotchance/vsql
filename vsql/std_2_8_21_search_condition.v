module vsql

// ISO/IEC 9075-2:2016(E), 8.21, <search condition>
//
// Specify a condition that is True, False, or Unknown, depending on the value
// of a <boolean value expression>.

// A WhereOperation executes a condition on each row, only passing through rows
// that evaluate to TRUE.
//
// ISO/IEC 9075-2:2016(E), 7.12, <where clause>, General Rules, 2
struct WhereOperation {
	condition BooleanValueExpression
	params    map[string]Value
	columns   Columns
	tables    map[string]&Table
mut:
	conn &Connection
	// compiled is the condition once it's compiled, which is when the plan is
	// made for a WHERE (see add_where_plan), or on the first row (see
	// eval_as_bool).
	compiled []CompileResult
}

fn new_where_operation(condition BooleanValueExpression, params map[string]Value, conn &Connection, columns Columns, tables map[string]&Table, compiled []CompileResult) &WhereOperation {
	return &WhereOperation{condition, params, columns, tables, conn, compiled}
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
	mut new_rows := []Row{cap: rows.len}

	for row in rows {
		mut ok := eval_as_bool(mut o.conn, row, o.condition, o.params, o.tables, mut o.compiled)!
		if ok {
			new_rows << row
		}
	}

	return new_rows
}

// eval_as_bool compiles e on the first row (compiled is empty) and keeps it in
// compiled for the rows after it.
fn eval_as_bool(mut conn Connection, data Row, e BooleanValueExpression, params map[string]Value, tables map[string]&Table, mut compiled []CompileResult) !bool {
	conn.check_canceled()!
	if compiled.len == 0 {
		mut c := Compiler{
			conn:   conn
			params: params
			tables: tables
		}
		compiled << e.compile(mut c)!
	}
	// ISO/IEC 9075-2:2016(E), 8.21, <search condition>, General Rules, 1
	v := compiled[0].run(mut conn, data, params)!

	if v.typ.typ == .is_boolean {
		return v.bool_value() == .is_true
	}

	return sqlstate_42804('in expression', 'BOOLEAN', v.typ.str())
}
