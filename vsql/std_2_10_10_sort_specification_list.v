module vsql

// ISO/IEC 9075-2:2023, 10.10, <sort specification list>
//
// Specify a sort order.

struct SortSpecification {
	expr   ValueExpression
	is_asc bool
	// nulls_first is true when null values are before every other value (NULLS
	// FIRST), whichever direction the sort is in.
	nulls_first bool
}

// new_sort_specification is a sort specification with an optional <null
// ordering> (true for NULLS FIRST). Without one, null values are less than every
// other value, so they're first for ASC and last for DESC.
//
// ISO/IEC 9075-2:2023, 10.10, <sort specification list>, Syntax Rules, 3
fn new_sort_specification(expr ValueExpression, is_asc bool, nulls_first ?bool) SortSpecification {
	return SortSpecification{expr, is_asc, nulls_first or { is_asc }}
}

// pstr only has the <null ordering> when it isn't the default, so the text of
// an aggregate function is the same with or without NULLS FIRST for ASC (or
// NULLS LAST for DESC), and it's different for a different order.
fn (e SortSpecification) pstr(params map[string]Value) string {
	direction := if e.is_asc { 'ASC' } else { 'DESC' }
	if e.nulls_first == e.is_asc {
		return '${e.expr.pstr(params)} ${direction}'
	}

	nulls := if e.nulls_first { 'FIRST' } else { 'LAST' }

	return '${e.expr.pstr(params)} ${direction} NULLS ${nulls}'
}
