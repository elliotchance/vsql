module vsql

// ISO/IEC 9075-2:2016(E), 7.1, <row value constructor>
//
// # Function
//
// Specify a value or list of values to be constructed into a row.
//
// # Format
//~
//~ <row value constructor> /* RowValueConstructor */ ::=
//~     <common value expression>          -> RowValueConstructor
//~   | <boolean value expression>         -> RowValueConstructor
//~   | <explicit row value constructor>   -> RowValueConstructor
//~
//~ <explicit row value constructor> /* ExplicitRowValueConstructor */ ::=
//~     ROW <left paren> <row value constructor element list>
//~     <right paren>                                           -> explicit_row_value_constructor_1
//~   | <row subquery>                                          -> ExplicitRowValueConstructor
//~
//~ <row value constructor element list> /* []ValueExpression */ ::=
//~     <row value constructor element>                -> row_value_constructor_element_list_1
//~   | <row value constructor element list> <comma>
//~     <row value constructor element>                -> row_value_constructor_element_list_2
//~
//~ <row value constructor element> /* ValueExpression */ ::=
//~     <value expression>
//~
//~ <contextually typed row value constructor> /* ContextuallyTypedRowValueConstructor */ ::=
//~     <common value expression>                        -> ContextuallyTypedRowValueConstructor
//~   | <boolean value expression>                       -> ContextuallyTypedRowValueConstructor
//~   | <contextually typed value specification>         -> ContextuallyTypedRowValueConstructor
//~   | <left paren> <contextually typed value specification>
//~     <right paren>                                    -> contextually_typed_row_value_constructor_1
//~   | <left paren>
//~     <contextually typed row value constructor element> <comma>
//~     <contextually typed row value constructor element list>
//~     <right paren>                                    -> contextually_typed_row_value_constructor_2
//~
//~ <contextually typed row value constructor element list> /* []ContextuallyTypedRowValueConstructorElement */ ::=
//~     <contextually typed row value constructor element>        -> contextually_typed_row_value_constructor_element_list_1
//~   | <contextually typed row value constructor element list>
//~     <comma>
//~     <contextually typed row value constructor element>        -> contextually_typed_row_value_constructor_element_list_2
//~
//~ <contextually typed row value constructor element> /* ContextuallyTypedRowValueConstructorElement */ ::=
//~     <value expression>                         -> ContextuallyTypedRowValueConstructorElement
//~   | <contextually typed value specification>   -> ContextuallyTypedRowValueConstructorElement
//~
//~ <row value constructor predicand> /* RowValueConstructorPredicand */ ::=
//~     <common value expression>   -> RowValueConstructorPredicand
//~   | <boolean predicand>         -> RowValueConstructorPredicand

type ContextuallyTypedRowValueConstructor = BooleanValueExpression
	| CommonValueExpression
	| NullSpecification
	| []ContextuallyTypedRowValueConstructorElement

fn (e ContextuallyTypedRowValueConstructor) pstr(params map[string]Value) string {
	return match e {
		CommonValueExpression, BooleanValueExpression, NullSpecification {
			e.pstr(params)
		}
		[]ContextuallyTypedRowValueConstructorElement {
			e.map(it.pstr(params)).join(', ')
		}
	}
}

fn (e ContextuallyTypedRowValueConstructor) compile(mut c Compiler) !CompileResult {
	match e {
		CommonValueExpression, BooleanValueExpression, NullSpecification {
			return e.compile(mut c)!
		}
		[]ContextuallyTypedRowValueConstructorElement {
			mut contains_agg := false
			for element in e {
				if element.compile(mut c)!.contains_agg {
					contains_agg = true
				}
			}

			return e[0].compile(mut c)!.with_agg(contains_agg)
		}
	}
}

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

struct ExplicitRowValueConstructorRow {
	exprs []ValueExpression
}

fn (e ExplicitRowValueConstructorRow) pstr(params map[string]Value) string {
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

fn (r RowValueConstructor) eval_row(mut conn Connection, data Row, params map[string]Value) !Row {
	mut col_number := 1
	mut row := map[string]Value{}
	mut c := Compiler{
		conn:   conn
		params: params
	}
	match r {
		ExplicitRowValueConstructor {
			match r {
				ExplicitRowValueConstructorRow {
					for expr in r.exprs {
						row['COL${col_number}'] = expr.compile(mut c)!.run(mut conn, data,
							params)!
						col_number++
					}
				}
				QueryExpression {
					panic('query expressions cannot be used in ROW constructors')
				}
			}
		}
		CommonValueExpression, BooleanValueExpression {
			row['COL${col_number}'] = r.compile(mut c)!.run(mut conn, data, params)!
		}
	}

	return Row{
		data: row
	}
}

type ExplicitRowValueConstructor = ExplicitRowValueConstructorRow | QueryExpression

fn (e ExplicitRowValueConstructor) pstr(params map[string]Value) string {
	return match e {
		ExplicitRowValueConstructorRow, QueryExpression {
			e.pstr(params)
		}
	}
}

fn (e ExplicitRowValueConstructor) compile(mut c Compiler) !CompileResult {
	// ExplicitRowValueConstructorRow should never make it to eval because it will
	// be reformatted into a ValuesOperation.
	//
	// QueryExpression will have already been resolved to a ValuesOperation.
	return sqlstate_42601('missing or invalid expression provided')
}

fn parse_explicit_row_value_constructor_1(exprs []ValueExpression) !ExplicitRowValueConstructor {
	return ExplicitRowValueConstructorRow{exprs}
}

fn parse_contextually_typed_row_value_constructor_1(e NullSpecification) !ContextuallyTypedRowValueConstructor {
	return e
}

fn parse_contextually_typed_row_value_constructor_2(element ContextuallyTypedRowValueConstructorElement, list []ContextuallyTypedRowValueConstructorElement) !ContextuallyTypedRowValueConstructor {
	mut new_list := []ContextuallyTypedRowValueConstructorElement{}
	new_list << element
	for e in list {
		new_list << e
	}

	return new_list
}

fn parse_row_value_constructor_element_list_1(expr ValueExpression) ![]ValueExpression {
	return [expr]
}

fn parse_row_value_constructor_element_list_2(element_list []ValueExpression, element ValueExpression) ![]ValueExpression {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}

fn parse_contextually_typed_row_value_constructor_element_list_1(expr ContextuallyTypedRowValueConstructorElement) ![]ContextuallyTypedRowValueConstructorElement {
	return [expr]
}

fn parse_contextually_typed_row_value_constructor_element_list_2(element_list []ContextuallyTypedRowValueConstructorElement, element ContextuallyTypedRowValueConstructorElement) ![]ContextuallyTypedRowValueConstructorElement {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}
