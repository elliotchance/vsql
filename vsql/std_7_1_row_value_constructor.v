module vsql

// ISO/IEC 9075-2:2016(E), 7.1, <row value constructor>
//
// Specify a value or list of values to be constructed into a row.

type ContextuallyTypedRowValueConstructor = BooleanValueExpression
	| CommonValueExpression
	| NullSpecification
	| []ContextuallyTypedRowValueConstructorElement

type ContextuallyTypedRowValueConstructorElement = NullSpecification | ValueExpression

fn (e ContextuallyTypedRowValueConstructorElement) pstr(params map[string]Value) string {
	return match e {
		ValueExpression, NullSpecification {
			e.pstr(params)
		}
	}
}

fn (e ContextuallyTypedRowValueConstructorElement) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, NullSpecification {
			return e.compile(mut c)!
		}
	}
}

type RowValueConstructorPredicand = BooleanPredicand | CommonValueExpression

fn (e RowValueConstructorPredicand) pstr(params map[string]Value) string {
	return match e {
		CommonValueExpression, BooleanPredicand {
			e.pstr(params)
		}
	}
}

fn (e RowValueConstructorPredicand) compile(mut c Compiler) !CompileResult {
	match e {
		CommonValueExpression, BooleanPredicand {
			return e.compile(mut c)!
		}
	}
}

// ExplicitRowValueConstructor is a "ROW (...)". A row subquery (F641) isn't
// supported yet, see unsupported_row_subquery.
struct ExplicitRowValueConstructor {
	exprs []ValueExpression
}

fn (e ExplicitRowValueConstructor) pstr(params map[string]Value) string {
	mut values := []string{}
	for expr in e.exprs {
		values << expr.pstr(params)
	}

	return values.join(', ')
}

type RowValueConstructor = BooleanValueExpression
	| CommonValueExpression
	| ExplicitRowValueConstructor

fn (e RowValueConstructor) pstr(params map[string]Value) string {
	return match e {
		CommonValueExpression, BooleanValueExpression, ExplicitRowValueConstructor {
			'ROW(' + e.pstr(params) + ')'
		}
	}
}

fn (e RowValueConstructor) compile(mut c Compiler) !CompileResult {
	match e {
		CommonValueExpression, BooleanValueExpression, ExplicitRowValueConstructor {
			return e.compile(mut c)!
		}
	}
}

// compile_elements compiles each value in the row, so a ROW (or a parenthesized
// list) has one for each column and anything else is a single column.
fn (r RowValueConstructor) compile_elements(mut c Compiler) ![]CompileResult {
	match r {
		ExplicitRowValueConstructor {
			return r.exprs.map(it.compile(mut c)!)
		}
		CommonValueExpression, BooleanValueExpression {
			return [r.compile(mut c)!]
		}
	}
}

fn (r RowValueConstructor) eval_row(mut conn Connection, data Row, params map[string]Value) !Row {
	mut c := Compiler{
		conn:   conn
		params: params
	}
	mut row := map[string]Value{}
	for i, element in r.compile_elements(mut c)! {
		row['COL${i + 1}'] = element.run(mut conn, data, params)!
	}

	return Row{
		data: row
	}
}

fn (e ExplicitRowValueConstructor) compile(mut c Compiler) !CompileResult {
	// ExplicitRowValueConstructor should never make it to eval because it will
	// be reformatted into a ValuesOperation.
	return sqlstate_42601('missing or invalid expression provided')
}

// unsupported_row_subquery is the error for a row subquery (F641), which isn't
// supported yet. It's raised when it's parsed.
fn unsupported_row_subquery() !ExplicitRowValueConstructor {
	return sqlstate_42601('subqueries are not supported in VALUES')
}
