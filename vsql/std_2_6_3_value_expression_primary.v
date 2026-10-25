module vsql

// ISO/IEC 9075-2:2016(E), 6.3, <value expression primary>
//
// Specify a value that is syntactically self-delimited.

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

// e is a reference because a ValueExpression can contain a
// ParenthesizedValueExpression, and V stores a sum type's value inline.
struct ParenthesizedValueExpression {
	e &ValueExpression
}

fn new_parenthesized_value_expression(e ValueExpression) ParenthesizedValueExpression {
	return ParenthesizedValueExpression{&e}
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
	| Subquery
	| ValueSpecification

fn (e NonparenthesizedValueExpressionPrimary) pstr(params map[string]Value) string {
	return match e {
		ValueSpecification, Identifier, AggregateFunction, RoutineInvocation, CaseExpression,
		CastSpecification, NextValueExpression, Subquery {
			e.pstr(params)
		}
	}
}

fn (e NonparenthesizedValueExpressionPrimary) compile(mut c Compiler) !CompileResult {
	match e {
		ValueSpecification, Identifier, AggregateFunction, CaseExpression, CastSpecification,
		NextValueExpression, RoutineInvocation, Subquery {
			return e.compile(mut c)!
		}
	}
}
