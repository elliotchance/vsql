// values.v contains logic for the VALUES statement.

module vsql

// A ValuesOperation provides a VALUES derived implicit table.
struct ValuesOperation {
	rows        []RowExpr
	offset      Expr
	correlation Correlation
	conn        &Connection
	params      map[string]Value
}

// TODO(elliotchance): It's important we return a pointer, otherwise there's
//  some weird memory issues where the rows can just disappear sometimes. I
//  suspect this is just immaturity with the garbage collector and the pointer
//  may be removed in the future. Run the test suite a few times and if it
//  passes you're in the clear.
fn new_values_operation(rows []RowExpr, offset Expr, correlation Correlation, conn &Connection, params map[string]Value) ?&ValuesOperation {
	if correlation.columns.len > 0 {
		for row in rows {
			if row.exprs.len != correlation.columns.len {
				return sqlstate_42601('ROW provides the wrong number of columns for the correlation')
			}
		}
	}

	return &ValuesOperation{rows, offset, correlation, conn, params}
}

fn (o &ValuesOperation) str() string {
	mut rows := []string{}
	for row in o.rows {
		rows << row.pstr(o.params)
	}

	return 'VALUES ${rows.join(', ')}$o.correlation'
}

fn (o &ValuesOperation) columns() []Identifier {
	if o.correlation.columns.len > 0 {
		return o.correlation.columns
	}

	mut columns := []Identifier{}

	// TODO(elliotchance): All check all exprs are RowExpr AND they have the
	//  right number of columns AND types.
	for i in 1 .. o.rows[0].exprs.len + 1 {
		columns << Identifier{
			name: 'COL$i'
		}
	}

	return columns
}

fn (o &ValuesOperation) execute(_ []Row) ?[]Row {
	mut offset := 0
	if o.offset !is NoExpr {
		offset = int((eval_as_value(o.conn, Row{}, o.offset, o.params) ?).f64_value)
	}

	mut rows := []Row{}
	if offset >= o.rows.len {
		return rows
	}

	for row in o.rows[offset..] {
		rows << eval_row(o.conn, Row{
			data: map[string]Value{}
		}, row.exprs, o.params) ?
	}

	column_names := o.columns()
	if column_names.len > 0 {
		for mut row in rows {
			mut data := map[string]Value{}
			for i in 1 .. row.data.len + 1 {
				name := identifier_name(column_names[i - 1].name)
				data[name] = row.data['COL$i']
			}

			row = Row{
				data: data
			}
		}
	}

	return rows
}
