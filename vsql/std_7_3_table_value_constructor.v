module vsql

// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>
//
// Specify a set of <row value expression>s to be constructed into a table.

type SimpleTable = QuerySpecification | []RowValueConstructor

// A ValuesOperation provides a VALUES derived implicit table.
struct ValuesOperation {
	rows        []RowValueConstructor
	correlation Correlation
	params      map[string]Value
	columns     Columns
mut:
	conn &Connection
}

// TODO(elliotchance): It's important we return a pointer, otherwise there's
//  some weird memory issues where the rows can just disappear sometimes. I
//  suspect this is just immaturity with the garbage collector and the pointer
//  may be removed in the future. Run the test suite a few times and if it
//  passes you're in the clear.
fn new_values_operation(rows []RowValueConstructor, correlation Correlation, mut conn Connection, params map[string]Value) !&ValuesOperation {
	mut c := Compiler{
		conn:   conn
		params: params
	}

	// All rows must have the same number of columns, and each column has the
	// combined type of that column in every row (9.5).
	//
	// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>, Syntax Rules, 1
	// and 4
	mut types := []Type{}
	for i, row in rows {
		compiled := row.compile_elements(mut c)!
		if i == 0 {
			types = compiled.map(Type{it.typ.typ, it.typ.size, it.typ.scale, false})
			continue
		}

		if compiled.len != types.len {
			return sqlstate_42601('VALUES rows must have the same number of columns')
		}

		for j, column in compiled {
			types[j] = combine_types(types[j], column.typ) or {
				return sqlstate_42804('in row ${i + 1}, column ${j + 1} of VALUES',
					types[j].str(), column.typ.str())
			}
		}
	}

	if correlation.columns.len > 0 && correlation.columns.len != types.len {
		return sqlstate_42601('ROW provides the wrong number of columns for the correlation')
	}

	mut columns := []Column{}
	for i, typ in types {
		name := if correlation.columns.len > 0 {
			correlation.columns[i]
		} else {
			Identifier{
				sub_entity_name: 'COL${i + 1}'
			}
		}
		columns << Column{
			name: name
			typ:  typ
		}
	}

	return &ValuesOperation{rows, correlation, params, columns, conn}
}

fn (o &ValuesOperation) str() string {
	mut rows := []string{}
	for row in o.rows {
		rows << row.pstr(o.params)
	}

	return 'VALUES (${o.columns()}) = ${rows.join(', ')}'
}

fn (o &ValuesOperation) columns() Columns {
	return o.columns
}

// execute returns every row. OFFSET and FETCH are a LimitOperation.
fn (mut o ValuesOperation) execute(_ []Row) ![]Row {
	mut rows := []Row{}
	for row in o.rows {
		o.conn.begin_row()
		rows << row.eval_row(mut o.conn, Row{
			data: map[string]Value{}
		}, o.params)!
	}

	columns := o.columns()
	if columns.len > 0 {
		for mut row in rows {
			mut data := map[string]Value{}
			for i in 1 .. row.data.len + 1 {
				column := columns[i - 1]
				data[column.name.sub_entity_name] = convert_to_combined_type(mut o.conn,
					'in VALUES', row.data['COL${i}'], column.typ)!
			}

			row = Row{
				data: data
			}
		}
	}

	return rows
}
