module vsql

// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>
//
// Specify a set of <row value expression>s to be constructed into a table.

type SimpleTable = QuerySpecification | []RowValueConstructor

fn (e SimpleTable) pstr(params map[string]Value) string {
	match e {
		QuerySpecification {
			return '<subquery>'
		}
		[]RowValueConstructor {
			mut elements := []string{}
			for element in e {
				elements << element.pstr(params)
			}

			return 'VALUES ${elements.join(', ')}'
		}
	}
}

// A ValuesOperation provides a VALUES derived implicit table.
struct ValuesOperation {
	rows        []RowValueConstructor
	offset      Value
	correlation Correlation
	params      map[string]Value
mut:
	conn &Connection
}

// TODO(elliotchance): It's important we return a pointer, otherwise there's
//  some weird memory issues where the rows can just disappear sometimes. I
//  suspect this is just immaturity with the garbage collector and the pointer
//  may be removed in the future. Run the test suite a few times and if it
//  passes you're in the clear.
fn new_values_operation(rows []RowValueConstructor, offset Value, correlation Correlation, mut conn Connection, params map[string]Value) !&ValuesOperation {
	if correlation.columns.len > 0 {
		for row in rows {
			match row {
				ExplicitRowValueConstructor {
					match row {
						ExplicitRowValueConstructorRow {
							if row.exprs.len != correlation.columns.len {
								return sqlstate_42601('ROW provides the wrong number of columns for the correlation')
							}
						}
						QueryExpression {
							panic('query expressions cannot be used in ROW constructors')
						}
					}
				}
				CommonValueExpression, BooleanValueExpression {
					// Nothing to validate in this case.
				}
			}
		}
	}

	return &ValuesOperation{rows, offset, correlation, params, conn}
}

fn (o &ValuesOperation) str() string {
	mut rows := []string{}
	for row in o.rows {
		rows << row.pstr(o.params)
	}

	return 'VALUES (${o.columns()}) = ${rows.join(', ')}'
}

fn (o &ValuesOperation) columns() Columns {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
	}
	e := o.rows[0]
	if o.correlation.columns.len > 0 {
		mut columns := []Column{}
		for i, column in o.correlation.columns {
			match e {
				ExplicitRowValueConstructor {
					match e {
						ExplicitRowValueConstructorRow {
							typ := (e.exprs[i].compile(mut c) or { panic(err) }).typ
							columns << Column{
								name: column
								typ:  typ
							}
						}
						QueryExpression {
							panic('query expressions cannot be used in ROW constructors')
						}
					}
				}
				CommonValueExpression, BooleanValueExpression {
					columns << Column{
						name: column
						typ:  (e.compile(mut c) or { panic(err) }).typ
					}
				}
			}
		}

		return columns
	}

	mut columns := []Column{}

	// TODO(elliotchance): All check all exprs are ExplicitRowValueConstructorRow
	//  AND they have the right number of columns AND types.
	match e {
		ExplicitRowValueConstructor {
			match e {
				ExplicitRowValueConstructorRow {
					for i in 1 .. e.exprs.len + 1 {
						typ := (e.exprs[i - 1].compile(mut c) or { panic(err) }).typ
						columns << Column{
							name: Identifier{
								sub_entity_name: 'COL${i}'
							}
							typ:  typ
						}
					}
				}
				QueryExpression {
					panic('query expressions cannot be used in ROW constructors')
				}
			}
		}
		CommonValueExpression, BooleanValueExpression {
			columns << Column{
				name: Identifier{
					sub_entity_name: 'COL1'
				}
				typ:  (e.compile(mut c) or { panic(err) }).typ
			}
		}
	}

	return columns
}

fn (mut o ValuesOperation) execute(_ []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
	}
	offset := int((o.offset.compile(mut c)!.run(mut o.conn, Row{}, o.params)!).f64_value())

	mut rows := []Row{}
	if offset >= o.rows.len {
		return rows
	}

	for row in o.rows[offset..] {
		rows << row.eval_row(mut o.conn, Row{
			data: map[string]Value{}
		}, o.params)!
	}

	columns := o.columns()
	if columns.len > 0 {
		for mut row in rows {
			mut data := map[string]Value{}
			for i in 1 .. row.data.len + 1 {
				name := columns[i - 1].name
				data[name.sub_entity_name] = row.data['COL${i}']
			}

			row = Row{
				data: data
			}
		}
	}

	return rows
}
