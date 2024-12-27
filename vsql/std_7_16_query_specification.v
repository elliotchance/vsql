module vsql

// ISO/IEC 9075-2:2016(E), 7.16, <query specification>
//
// Specify a table derived from the result of a <table expression>.

struct DerivedColumn {
	expr      ValueExpression
	as_clause Identifier // will be empty if not provided
}

type SelectList = AsteriskExpr | QualifiedAsteriskExpr | []DerivedColumn

type AsteriskExpr = bool

struct QualifiedAsteriskExpr {
	table_name Identifier
}

fn (e QualifiedAsteriskExpr) str() string {
	return '${e.table_name}.*'
}

struct QuerySpecification {
	exprs            SelectList
	table_expression TableExpression
	offset           ?ValueExpression
	fetch            ?ValueExpression
}
