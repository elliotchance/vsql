module vsql

// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>
//
// Specify a list of updates.

type UpdateSource = ContextuallyTypedValueSpecification | ValueExpression

struct SetClause {
	column_name string
	source      UpdateSource
}

fn (e UpdateSource) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, ContextuallyTypedValueSpecification {
			return e.compile(mut c)!
		}
	}
}
