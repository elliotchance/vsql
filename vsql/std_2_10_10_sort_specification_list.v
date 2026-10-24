module vsql

// ISO/IEC 9075-2:2016(E), 10.10, <sort specification list>
//
// Specify a sort order.

struct SortSpecification {
	expr   ValueExpression
	is_asc bool
}

fn (e SortSpecification) pstr(params map[string]Value) string {
	if e.is_asc {
		return '${e.expr.pstr(params)} ASC'
	}

	return '${e.expr.pstr(params)} DESC'
}
