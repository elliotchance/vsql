module vsql

// ISO/IEC 9075-2:2016(E), 6.3, <value expression primary>
//
// # Function
//
// Specify a value that is syntactically self-delimited.
//
// # Format
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

fn (e ValueExpressionPrimary) compile(mut c Compiler) !CompileResult {
	match e {
		ParenthesizedValueExpression, NonparenthesizedValueExpressionPrimary {
			return e.compile(mut c)!
		}
	}
}

struct ParenthesizedValueExpression {
	e ValueExpression
}

fn (e ParenthesizedValueExpression) pstr(params map[string]Value) string {
	return '(${e.e.pstr(params)})'
}

fn (e ParenthesizedValueExpression) compile(mut c Compiler) !CompileResult {
	return e.e.compile(mut c)!
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

fn (e NonparenthesizedValueExpressionPrimary) compile(mut c Compiler) !CompileResult {
	match e {
		ValueSpecification, Identifier, AggregateFunction, CaseExpression, CastSpecification,
		NextValueExpression, RoutineInvocation {
			return e.compile(mut c)!
		}
	}
}
