// ISO/IEC 9075-2:2016(E), 6.3, <value expression primary>

module vsql

// Format
//~
//~ <value expression primary> /* ValueExpressionPrimary */ ::=
//~     <parenthesized value expression>              -> ValueExpressionPrimary
//~   | <nonparenthesized value expression primary>   -> ValueExpressionPrimary
//~
//~ <parenthesized value expression> /* ParenthesizedValueExpression */ ::=
//~     <left paren> <value expression> <right paren>   -> parenthesized_value_expression
//~
//~ <nonparenthesized value expression primary> /* NonparenthesizedValueExpressionPrimary */ ::=
//~     <unsigned value specification>   -> NonparenthesizedValueExpressionPrimary
//~   | <column reference>               -> NonparenthesizedValueExpressionPrimary
//~   | <set function specification>     -> NonparenthesizedValueExpressionPrimary
//~   | <routine invocation>             -> NonparenthesizedValueExpressionPrimary
//~   | <case expression>                -> NonparenthesizedValueExpressionPrimary
//~   | <cast specification>             -> NonparenthesizedValueExpressionPrimary
//~   | <next value expression>          -> NonparenthesizedValueExpressionPrimary

type ValueExpressionPrimary = NonparenthesizedValueExpressionPrimary
	| ParenthesizedValueExpression

fn (e ValueExpressionPrimary) pstr(params map[string]Value) string {
	return match e {
		ParenthesizedValueExpression, NonparenthesizedValueExpressionPrimary {
			e.pstr(params)
		}
	}
}

fn (e ValueExpressionPrimary) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		ParenthesizedValueExpression, NonparenthesizedValueExpressionPrimary {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e ValueExpressionPrimary) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		ParenthesizedValueExpression, NonparenthesizedValueExpressionPrimary {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e ValueExpressionPrimary) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		ParenthesizedValueExpression, NonparenthesizedValueExpressionPrimary {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e ValueExpressionPrimary) resolve_identifiers(conn &Connection, tables map[string]Table) !ValueExpressionPrimary {
	return match e {
		ParenthesizedValueExpression {
			e.resolve_identifiers(conn, tables)!
		}
		NonparenthesizedValueExpressionPrimary {
			e.resolve_identifiers(conn, tables)!
		}
	}
}

struct ParenthesizedValueExpression {
	e ValueExpression
}

fn (e ParenthesizedValueExpression) pstr(params map[string]Value) string {
	return '(${e.e.pstr(params)})'
}

fn (e ParenthesizedValueExpression) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return e.e.eval(mut conn, data, params)!
}

fn (e ParenthesizedValueExpression) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return e.e.eval_type(conn, data, params)
}

fn (e ParenthesizedValueExpression) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return e.e.is_agg(conn, row, params)!
}

fn (e ParenthesizedValueExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !ParenthesizedValueExpression {
	return ParenthesizedValueExpression{e.e.resolve_identifiers(conn, tables)!}
}

type NonparenthesizedValueExpressionPrimary = AggregateFunction
	| CaseExpression
	| CastSpecification
	| Identifier
	| NextValueExpression
	| RoutineInvocation
	| ValueSpecification

fn (e NonparenthesizedValueExpressionPrimary) pstr(params map[string]Value) string {
	return match e {
		ValueSpecification, Identifier, AggregateFunction, RoutineInvocation, CaseExpression,
		CastSpecification, NextValueExpression {
			e.pstr(params)
		}
	}
}

fn (e NonparenthesizedValueExpressionPrimary) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		ValueSpecification, Identifier, AggregateFunction, CaseExpression, CastSpecification,
		NextValueExpression, RoutineInvocation {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e NonparenthesizedValueExpressionPrimary) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		ValueSpecification, Identifier, AggregateFunction, CaseExpression, CastSpecification,
		NextValueExpression, RoutineInvocation {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e NonparenthesizedValueExpressionPrimary) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		ValueSpecification, AggregateFunction, CaseExpression, CastSpecification,
		NextValueExpression, RoutineInvocation, Identifier {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e NonparenthesizedValueExpressionPrimary) resolve_identifiers(conn &Connection, tables map[string]Table) !NonparenthesizedValueExpressionPrimary {
	match e {
		ValueSpecification {
			return e.resolve_identifiers(conn, tables)!
		}
		AggregateFunction {
			return e.resolve_identifiers(conn, tables)!
		}
		CaseExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		CastSpecification {
			return e.resolve_identifiers(conn, tables)!
		}
		NextValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		RoutineInvocation {
			return e.resolve_identifiers(conn, tables)!
		}
		Identifier {
			return e.resolve_identifiers(conn, tables)!
		}
	}
}

fn parse_parenthesized_value_expression(e ValueExpression) !ParenthesizedValueExpression {
	return ParenthesizedValueExpression{e}
}
