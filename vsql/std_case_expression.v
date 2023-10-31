module vsql

// ISO/IEC 9075-2:2016(E), 6.12, <case expression>
//
// # Function
//
// Specify a conditional value.
//
// # Format
//~
//~ <case expression> /* CaseExpression */ ::=
//~     <case abbreviation>
//~
//~ <case abbreviation> /* CaseExpression */ ::=
//~     NULLIF <left paren> <value expression>
//~     <comma> <value expression> <right paren>                      -> nullif
//~   | COALESCE <left paren> <value expression list> <right paren>   -> coalesce
//
// These are non-standard, just to simplify standard rules:
//~
//~ <value expression list> /* []ValueExpression */ ::=
//~     <value expression>                                   -> value_expression_list_1
//~   | <value expression list> <comma> <value expression>   -> value_expression_list_2

type CaseExpression = CaseExpressionCoalesce | CaseExpressionNullIf

fn (e CaseExpression) pstr(params map[string]Value) string {
	return match e {
		CaseExpressionNullIf {
			'NULLIF(${e.a.pstr(params)}, ${e.b.pstr(params)})'
		}
		CaseExpressionCoalesce {
			'COALESCE(${e.exprs.map(it.pstr(params)).join(', ')})'
		}
	}
}

fn (e CaseExpression) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	match e {
		CaseExpressionNullIf {
			a := e.a.eval(mut conn, data, params)!
			b := e.b.eval(mut conn, data, params)!

			if a.typ.typ != b.typ.typ {
				return sqlstate_42804('in NULLIF', a.typ.str(), b.typ.str())
			}

			cmp := compare(a, b)!
			if cmp == .is_equal {
				return new_null_value(a.typ.typ)
			}

			return a
		}
		CaseExpressionCoalesce {
			// TODO(elliotchance): This is horribly inefficient.

			mut typ := SQLType.is_varchar
			mut first := true
			for i, expr in e.exprs {
				typ2 := expr.eval_type(conn, data, params)!

				if first {
					typ = typ2.typ
					first = false
				} else if typ != typ2.typ {
					return sqlstate_42804('in argument ${i + 1} of COALESCE', typ.str(),
						typ2.typ.str())
				}
			}

			mut value := Value{}
			for expr in e.exprs {
				value = expr.eval(mut conn, data, params)!

				if !value.is_null {
					return value
				}
			}

			return new_null_value(value.typ.typ)
		}
	}
}

fn (e CaseExpression) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		CaseExpressionNullIf { e.a.eval_type(conn, data, params)! }
		CaseExpressionCoalesce { e.exprs[0].eval_type(conn, data, params)! }
	}
}

fn (e CaseExpression) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	match e {
		CaseExpressionNullIf {
			if e.a.is_agg(conn, row, params)! || e.b.is_agg(conn, row, params)! {
				return sqlstate_42601('nested aggregate functions are not supported: ${CaseExpression(e).pstr(params)}')
			}
		}
		CaseExpressionCoalesce {
			for expr in e.exprs {
				return expr.is_agg(conn, row, params)!
			}
		}
	}

	return false
}

fn (e CaseExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !CaseExpression {
	match e {
		CaseExpressionNullIf {
			return CaseExpressionNullIf{e.a.resolve_identifiers(conn, tables)!, e.b.resolve_identifiers(conn,
				tables)!}
		}
		CaseExpressionCoalesce {
			return CaseExpressionCoalesce{e.exprs.map(it.resolve_identifiers(conn, tables)!)}
		}
	}
}

struct CaseExpressionNullIf {
	a ValueExpression
	b ValueExpression
}

struct CaseExpressionCoalesce {
	exprs []ValueExpression
}

fn parse_nullif(a ValueExpression, b ValueExpression) !CaseExpression {
	return CaseExpressionNullIf{a, b}
}

fn parse_coalesce(exprs []ValueExpression) !CaseExpression {
	return CaseExpressionCoalesce{exprs}
}

fn parse_value_expression_list_1(e ValueExpression) ![]ValueExpression {
	return [e]
}

fn parse_value_expression_list_2(element_list []ValueExpression, element ValueExpression) ![]ValueExpression {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}
