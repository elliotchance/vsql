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

fn (e ContextuallyTypedRowValueConstructor) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		CommonValueExpression, BooleanValueExpression, NullSpecification {
			e.eval(mut conn, data, params)!
		}
		[]ContextuallyTypedRowValueConstructorElement {
			e[0].eval(mut conn, data, params)!
		}
	}
}

fn (e ContextuallyTypedRowValueConstructor) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		CommonValueExpression, BooleanValueExpression, NullSpecification {
			e.eval_type(conn, data, params)!
		}
		[]ContextuallyTypedRowValueConstructorElement {
			e[0].eval_type(conn, data, params)!
		}
	}
}

fn (e ContextuallyTypedRowValueConstructor) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		CommonValueExpression, BooleanValueExpression, NullSpecification {
			e.is_agg(conn, row, params)!
		}
		[]ContextuallyTypedRowValueConstructorElement {
			for element in e {
				if element.is_agg(conn, row, params)! {
					return true
				}
			}

			return false
		}
	}
}

fn (e ContextuallyTypedRowValueConstructor) resolve_identifiers(conn &Connection, tables map[string]Table) !ContextuallyTypedRowValueConstructor {
	match e {
		CommonValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		BooleanValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		NullSpecification {
			return e.resolve_identifiers(conn, tables)!
		}
		[]ContextuallyTypedRowValueConstructorElement {
			return e.map(it.resolve_identifiers(conn, tables)!)
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

fn (e ContextuallyTypedRowValueConstructorElement) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		ValueExpression, NullSpecification {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e ContextuallyTypedRowValueConstructorElement) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		ValueExpression, NullSpecification {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e ContextuallyTypedRowValueConstructorElement) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		ValueExpression, NullSpecification {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e ContextuallyTypedRowValueConstructorElement) resolve_identifiers(conn &Connection, tables map[string]Table) !ContextuallyTypedRowValueConstructorElement {
	match e {
		ValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		NullSpecification {
			return e.resolve_identifiers(conn, tables)!
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

fn (e RowValueConstructorPredicand) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		CommonValueExpression, BooleanPredicand {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e RowValueConstructorPredicand) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		CommonValueExpression, BooleanPredicand {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e RowValueConstructorPredicand) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		CommonValueExpression, BooleanPredicand {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e RowValueConstructorPredicand) resolve_identifiers(conn &Connection, tables map[string]Table) !RowValueConstructorPredicand {
	return match e {
		CommonValueExpression {
			e.resolve_identifiers(conn, tables)!
		}
		BooleanPredicand {
			e.resolve_identifiers(conn, tables)!
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

fn (e ExplicitRowValueConstructorRow) resolve_identifiers(conn &Connection, tables map[string]Table) !ExplicitRowValueConstructorRow {
	mut new_exprs := []ValueExpression{}

	for expr in e.exprs {
		new_exprs << expr.resolve_identifiers(conn, tables)!
	}

	return ExplicitRowValueConstructorRow{new_exprs}
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

fn (e RowValueConstructor) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		CommonValueExpression, BooleanValueExpression, ExplicitRowValueConstructor {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e RowValueConstructor) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		CommonValueExpression, BooleanValueExpression, ExplicitRowValueConstructor {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (r RowValueConstructor) eval_row(mut conn Connection, data Row, params map[string]Value) !Row {
	mut col_number := 1
	mut row := map[string]Value{}
	match r {
		ExplicitRowValueConstructor {
			match r {
				ExplicitRowValueConstructorRow {
					for expr in r.exprs {
						row['COL${col_number}'] = expr.eval(mut conn, data, params)!
						col_number++
					}
				}
				QueryExpression {
					panic('query expressions cannot be used in ROW constructors')
				}
			}
		}
		CommonValueExpression, BooleanValueExpression {
			row['COL${col_number}'] = r.eval(mut conn, data, params)!
		}
	}

	return Row{
		data: row
	}
}

fn (e RowValueConstructor) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		CommonValueExpression, BooleanValueExpression, ExplicitRowValueConstructor {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e RowValueConstructor) resolve_identifiers(conn &Connection, tables map[string]Table) !RowValueConstructor {
	match e {
		CommonValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		BooleanValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		ExplicitRowValueConstructor {
			return e.resolve_identifiers(conn, tables)!
		}
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

fn (e ExplicitRowValueConstructor) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	// ExplicitRowValueConstructorRow should never make it to eval because it will
	// be reformatted into a ValuesOperation.
	//
	// QueryExpression will have already been resolved to a ValuesOperation.
	return sqlstate_42601('missing or invalid expression provided')
}

fn (e ExplicitRowValueConstructor) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return sqlstate_42601('invalid expression provided: ${e.pstr(params)}')
}

fn (e ExplicitRowValueConstructor) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return false
}

fn (e ExplicitRowValueConstructor) resolve_identifiers(conn &Connection, tables map[string]Table) !ExplicitRowValueConstructor {
	match e {
		ExplicitRowValueConstructorRow {
			return e.resolve_identifiers(conn, tables)!
		}
		QueryExpression {
			// TODO(elliotchance): Is this correct? It was copied during refactoring
			//  but QueryExpression does contain some stuff that might need to be
			//  resolved. I won't fix it now since resolve_identifiers will be
			//  replaced by a more formal compiler soon.
			return e
		}
	}
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
