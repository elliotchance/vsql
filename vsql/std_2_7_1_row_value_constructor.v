module vsql

// ISO/IEC 9075-2:2023, 7.1, <row value constructor>
//
// Specify a value or list of values to be constructed into a row.

type ContextuallyTypedRowValueConstructor = BooleanValueExpression
	| CommonValueExpression
	| ContextuallyTypedValueSpecification
	| []ContextuallyTypedRowValueConstructorElement

type ContextuallyTypedRowValueConstructorElement = ContextuallyTypedValueSpecification
	| ValueExpression

fn (e ContextuallyTypedRowValueConstructorElement) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, ContextuallyTypedValueSpecification {
			return e.compile(mut c)!
		}
	}
}

type RowValueConstructorPredicand = BooleanPredicand
	| CommonValueExpression
	| ExplicitRowValueConstructor

fn (e RowValueConstructorPredicand) pstr(params map[string]Value) string {
	return match e {
		CommonValueExpression, BooleanPredicand {
			e.pstr(params)
		}
		ExplicitRowValueConstructor {
			'ROW(${e.pstr(params)})'
		}
	}
}

// compile is for a predicand that must be a single value. Only the predicates
// that are defined in terms of a comparison (and IS NULL) can have a row (see
// compile_fields).
fn (e RowValueConstructorPredicand) compile(mut c Compiler) !CompileResult {
	match e {
		CommonValueExpression, BooleanPredicand {
			return e.compile(mut c)!
		}
		ExplicitRowValueConstructor {
			return sqlstate_42601('a row value cannot be used here')
		}
	}
}

// compile_fields compiles each field of the predicand, so a row has one for
// each of its values and anything else is a single field.
fn (e RowValueConstructorPredicand) compile_fields(mut c Compiler) ![]CompileResult {
	return match e {
		ExplicitRowValueConstructor { e.exprs.map(it.compile(mut c)!) }
		CommonValueExpression, BooleanPredicand {
			if e.is_case_operand() {
				c.case_operands.last()
			} else {
				[e.compile(mut c)!]
			}
		}
	}
}

// ExplicitRowValueConstructor is a "ROW (...)". A row subquery (F641) isn't
// supported yet. A subquery in a row is a scalar subquery, so it must have one
// column.
struct ExplicitRowValueConstructor {
	exprs []ValueExpression
}

// new_explicit_row_value_constructor is for a row in parentheses, which is
// parsed with contextually typed elements. NULL and DEFAULT aren't a
// <row value constructor element>, so they're rejected here.
fn new_explicit_row_value_constructor(elements []ContextuallyTypedRowValueConstructorElement) !ExplicitRowValueConstructor {
	mut exprs := []ValueExpression{}
	for element in elements {
		match element {
			ValueExpression { exprs << element }
			ContextuallyTypedValueSpecification {
				return match element {
					DefaultSpecification { sqlstate_42601('unexpected DEFAULT') }
					NullSpecification { sqlstate_42601('unexpected NULL') }
				}
			}
		}
	}

	return ExplicitRowValueConstructor{exprs}
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
		conn:              conn
		params:            params
		aggregation_query: values_aggregation_query(conn)
	}
	mut row := map[string]Value{}
	for i, element in r.compile_elements(mut c)! {
		row['COL${i + 1}'] = element.run(mut conn, data, params)!
	}

	return Row{
		data: new_row_data_from_map(row)
	}
}

fn (e ExplicitRowValueConstructor) compile(mut _ Compiler) !CompileResult {
	// ExplicitRowValueConstructor should never make it to eval because it will
	// be reformatted into a ValuesOperation.
	return sqlstate_42601('missing or invalid expression provided')
}
