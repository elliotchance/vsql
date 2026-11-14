module vsql

// ISO/IEC 9075-2:2023, 14.15, <set clause list>
//
// Specify a list of updates.

type UpdateSource = ContextuallyTypedValueSpecification | ValueExpression

struct SetClause {
	column_name string
	source      UpdateSource
}

// compile compiles the value of a <set clause>. An aggregate function can't be
// used, since an UPDATE isn't a query that could have a group for it to be
// calculated over. That includes an aggregate function in a subquery of only
// the columns of the table being updated.
//
// ISO/IEC 9075-2:2023, 14.15, <set clause list>, Syntax Rules, 6
// ISO/IEC 9075-2:2023, 6.9, <set function specification>, Syntax Rules, 7
fn (e UpdateSource) compile(mut c Compiler) !CompileResult {
	compiled := match e {
		ValueExpression, ContextuallyTypedValueSpecification {
			e.compile(mut c)!
		}
	}

	if compiled.contains_agg {
		return sqlstate_42601('an aggregate function cannot be used in SET')
	}

	return compiled
}
