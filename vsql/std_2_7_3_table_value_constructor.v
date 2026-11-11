module vsql

// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>
//
// Specify a set of <row value expression>s to be constructed into a table.

// SimpleTable is also used for the other forms of a <query expression body>
// (see 7.17), which can contain a SimpleTable.
type SimpleTable = ParenthesizedQueryExpression
	| QuerySpecification
	| SetOperation
	| []RowValueConstructor

fn (e SimpleTable) pstr(params map[string]Value) string {
	match e {
		QuerySpecification, SetOperation, ParenthesizedQueryExpression {
			return e.pstr(params)
		}
		[]RowValueConstructor {
			mut rows := []string{}
			for row in e {
				rows << match row {
					CommonValueExpression, BooleanValueExpression { row.pstr(params) }
					ExplicitRowValueConstructor { 'ROW(${row.pstr(params)})' }
				}
			}

			return 'VALUES ${rows.join(', ')}'
		}
	}
}

// A ValuesOperation provides a VALUES derived implicit table.
struct ValuesOperation {
	rows        []RowValueConstructor
	correlation Correlation
	params      map[string]Value
	columns     Columns
mut:
	conn &Connection
}

// values_aggregation_query is the subquery scope of the query that an aggregate
// function without any column references is an aggregate of, when it's in a
// VALUES being planned or evaluated. A VALUES isn't a query specification, so
// it's the innermost query specification that contains it, such as the SELECT of
// "SELECT (VALUES COUNT(*)) FROM t". It's -1 if there isn't one. A derived table
// is in the FROM of its query specification, which can't have an aggregate
// function, so a VALUES there doesn't have one either.
//
// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 6.a and 7
fn values_aggregation_query(conn &Connection) int {
	if conn.in_derived_table || conn.subquery_scopes.len == 0 {
		return -1
	}

	return conn.subquery_scopes.last().aggregation_query or { conn.subquery_scopes.len - 1 }
}

// It's important we return a pointer, otherwise the rows can disappear.
fn new_values_operation(rows []RowValueConstructor, correlation Correlation, mut conn Connection, params map[string]Value) !&ValuesOperation {
	// NEXT VALUE FOR can be in the VALUES of an INSERT (a <from constructor>,
	// see InsertStatement), but not in a VALUES that's a query. Use "SELECT
	// NEXT VALUE FOR s FROM (VALUES 1) AS t" instead.
	//
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 1
	mut c := Compiler{
		conn:                   conn
		params:                 params
		next_value_not_allowed: 'VALUES'
		aggregation_query:      values_aggregation_query(conn)
	}

	// All rows must have the same number of columns, and each column has the
	// combined type of that column in every row (9.5).
	//
	// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>, Syntax Rules, 1
	// and 4
	mut compiled_rows := [][]CompileResult{}
	for row in rows {
		compiled_rows << row.compile_elements(mut c)!
	}

	// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 5.a.xix.1.B
	compiled_rows = c.with_row_types(compiled_rows)

	mut types := []Type{}
	for i, compiled in compiled_rows {

		// An aggregate function of an outer query (which is a value here) is allowed.
		//
		// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 7
		if compiled.any(it.contains_agg) {
			return sqlstate_42601('an aggregate function cannot be used in VALUES')
		}

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
		// The column names are implementation-dependent (Syntax Rule 4), unless
		// there is a correlation.
		columns << Column{
			name:    name
			typ:     typ
			unnamed: correlation.columns.len == 0
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
			data: RowData{}
		}, o.params)!
	}

	columns := o.columns()
	if columns.len > 0 {
		for mut row in rows {
			mut data := RowData{}
			for i in 1 .. row.data.len() + 1 {
				column := columns[i - 1]
				data.set(column.name.sub_entity_name, convert_to_combined_type(mut o.conn,
					'in VALUES', row.data.value('COL${i}'), column.typ)!)
			}

			row = Row{
				data: data
			}
		}
	}

	return rows
}
