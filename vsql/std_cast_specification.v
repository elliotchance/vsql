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

fn (e CastOperand) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, NullSpecification {
			return e.compile(mut c)!
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

fn (e CastSpecification) compile(mut c Compiler) !CompileResult {
	compiled_expr := e.expr.compile(mut c)!

	return CompileResult{
		run: fn [e, compiled_expr] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_expr.run(mut conn, data, params)!

			return cast(mut conn, 'for CAST', value, e.target)!
		}
		typ: e.target
		contains_agg: compiled_expr.contains_agg
	}
}

fn parse_cast(expr CastOperand, typ Type) !CastSpecification {
	return CastSpecification{expr, typ}
}
