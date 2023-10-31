module vsql

// ISO/IEC 9075-2:2016(E), 10.10, <sort specification list>
//
// # Function
//
// Specify a sort order.
//
// # Format
//~
//~ <sort specification list> /* []SortSpecification */ ::=
//~     <sort specification>                                     -> sort_list_1
//~   | <sort specification list> <comma> <sort specification>   -> sort_list_2
//~
//~ <sort specification> /* SortSpecification */ ::=
//~     <sort key>                            -> sort_1
//~   | <sort key> <ordering specification>   -> sort_2
//~
//~ <sort key> /* ValueExpression */ ::=
//~     <value expression>
//~
//~ <ordering specification> /* bool */ ::=
//~     ASC    -> yes
//~   | DESC   -> no

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

fn parse_sort_list_1(spec SortSpecification) ![]SortSpecification {
	return [spec]
}

fn parse_sort_list_2(specs []SortSpecification, spec SortSpecification) ![]SortSpecification {
	mut specs2 := specs.clone()
	specs2 << spec

	return specs2
}

fn parse_sort_1(expr ValueExpression) !SortSpecification {
	return SortSpecification{expr, true}
}

fn parse_sort_2(expr ValueExpression, is_asc bool) !SortSpecification {
	return SortSpecification{expr, is_asc}
}
