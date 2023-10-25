// ISO/IEC 9075-2:2016(E), 10.10, <sort specification list>

module vsql

// Format
//~
//~ <sort specification list> /* []SortSpecification */ ::=
//~     <sort specification>                                     -> sort_list1
//~   | <sort specification list> <comma> <sort specification>   -> sort_list2
//~
//~ <sort specification> /* SortSpecification */ ::=
//~     <sort key>                            -> sort1
//~   | <sort key> <ordering specification>   -> sort2
//~
//~ <sort key> /* Expr */ ::=
//~     <value expression>
//~
//~ <ordering specification> /* bool */ ::=
//~     ASC    -> yes
//~   | DESC   -> no

fn parse_sort_list1(spec SortSpecification) ![]SortSpecification {
	return [spec]
}

fn parse_sort_list2(specs []SortSpecification, spec SortSpecification) ![]SortSpecification {
	mut specs2 := specs.clone()
	specs2 << spec

	return specs2
}

fn parse_sort1(expr Expr) !SortSpecification {
	return SortSpecification{expr, true}
}

fn parse_sort2(expr Expr, is_asc bool) !SortSpecification {
	return SortSpecification{expr, is_asc}
}
