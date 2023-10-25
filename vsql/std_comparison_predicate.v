// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>

module vsql

// Format
//~
//~ <comparison predicate> /* Expr */ ::=
//~     <row value predicand> <comparison predicate part 2>   -> comparison
//~
//~ <comparison predicate part 2> /* ComparisonPredicatePart2 */ ::=
//~     <comp op> <row value predicand>   -> comparison_part
//~
//~ <comp op> /* string */ ::=
//~     <equals operator>
//~   | <not equals operator>
//~   | <less than operator>
//~   | <greater than operator>
//~   | <less than or equals operator>
//~   | <greater than or equals operator>

fn parse_comparison_part(op string, expr Expr) !ComparisonPredicatePart2 {
	return ComparisonPredicatePart2{op, expr}
}

fn parse_comparison(expr Expr, comp ComparisonPredicatePart2) !Expr {
	return BinaryExpr{expr, comp.op, comp.expr}
}
