module vsql

// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>
//
// # Function
//
// Specify a data conversion.
//
// # Format
//~
//~ <cast specification> /* CastSpecification */ ::=
//~     CAST <left paren> <cast operand> AS <cast target> <right paren>   -> cast
//~
//~ <cast operand> /* CastOperand */ ::=
//~     <value expression>                       -> CastOperand
//~   | <implicitly typed value specification>   -> CastOperand
//~
//~ <cast target> /* Type */ ::=
//~     <data type>

type CastOperand = NullSpecification | ValueExpression

fn (e CastOperand) pstr(params map[string]Value) string {
	return match e {
		ValueExpression, NullSpecification {
			e.pstr(params)
		}
	}
}

fn (e CastOperand) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		ValueExpression, NullSpecification {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e CastOperand) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		ValueExpression, NullSpecification {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e CastOperand) resolve_identifiers(conn &Connection, tables map[string]Table) !CastOperand {
	match e {
		ValueExpression {
			return e.resolve_identifiers(conn, tables)!
		}
		NullSpecification {
			return e.resolve_identifiers(conn, tables)!
		}
	}
}

struct CastSpecification {
	expr   CastOperand
	target Type
}

fn (e CastSpecification) pstr(params map[string]Value) string {
	return 'CAST(${e.expr.pstr(params)} AS ${e.target})'
}

fn (e CastSpecification) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	value := e.expr.eval(mut conn, data, params)!

	return cast(mut conn, 'for CAST', value, e.target)
}

fn (e CastSpecification) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return e.target
}

fn (e CastSpecification) resolve_identifiers(conn &Connection, tables map[string]Table) !CastSpecification {
	return CastSpecification{e.expr.resolve_identifiers(conn, tables)!, e.target}
}

fn parse_cast(expr CastOperand, typ Type) !CastSpecification {
	return CastSpecification{expr, typ}
}
