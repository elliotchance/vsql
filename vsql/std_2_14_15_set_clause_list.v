module vsql

// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>
//
// Specify a list of updates.

type UpdateSource = ContextuallyTypedValueSpecification | ValueExpression

struct SetClause {
	column_name string
	source      UpdateSource
}

// compile compiles the value of a <set clause>. An aggregate function can't be
// used, since there's no group for it to be calculated over, so it's a syntax
// error (as an unknown column).
//
// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>, Syntax Rules, 6
fn (e UpdateSource) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, ContextuallyTypedValueSpecification {
			return e.compile(mut c)!
		}
	}
}
