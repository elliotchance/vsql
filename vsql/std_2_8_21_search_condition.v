module vsql

// ISO/IEC 9075-2:2016(E), 8.21, <search condition>
//
// Specify a condition that is True, False, or Unknown, depending on the value
// of a <boolean value expression>.

// A WhereOperation executes a condition on each row, only passing through rows
// that evaluate to TRUE.
struct WhereOperation {
	condition BooleanValueExpression
	params    map[string]Value
	columns   Columns
	tables    map[string]Table
mut:
	conn &Connection
}

fn new_where_operation(condition BooleanValueExpression, params map[string]Value, conn &Connection, columns Columns, tables map[string]Table) &WhereOperation {
	return &WhereOperation{condition, params, columns, tables, conn}
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
		mut ok := eval_as_bool(mut o.conn, row, o.condition, o.params, o.tables)!
		if ok {
			new_rows << row
		}
	}

	return new_rows
}

fn eval_as_bool(mut conn Connection, data Row, e BooleanValueExpression, params map[string]Value, tables map[string]Table) !bool {
	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}
	v := e.compile(mut c)!.run(mut conn, data, params)!

	if v.typ.typ == .is_boolean {
		return v.bool_value() == .is_true
	}

	return sqlstate_42804('in expression', 'BOOLEAN', v.typ.str())
}
