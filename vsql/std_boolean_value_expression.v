// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>

module vsql

// Format
//~
//~ <boolean value expression> /* Expr */ ::=
//~     <boolean term>
//~   | <boolean value expression> OR <boolean term>   -> or
//~
//~ <boolean term> /* Expr */ ::=
//~     <boolean factor>
//~   | <boolean term> AND <boolean factor>   -> and
//~
//~ <boolean factor> /* Expr */ ::=
//~     <boolean test>
//~   | NOT <boolean test>   -> not
//~
//~ <boolean test> /* Expr */ ::=
//~     <boolean primary>
//~   | <boolean primary> IS <truth value>       -> boolean_test1
//~   | <boolean primary> IS NOT <truth value>   -> boolean_test2
//~
//~ <truth value> /* Value */ ::=
//~     TRUE      -> true
//~   | FALSE     -> false
//~   | UNKNOWN   -> unknown
//~
//~ <boolean primary> /* Expr */ ::=
//~     <predicate>
//~   | <boolean predicand>
//~
//~ <boolean predicand> /* Expr */ ::=
//~     <parenthesized boolean value expression>
//~   | <nonparenthesized value expression primary>
//~
//~ <parenthesized boolean value expression> /* Expr */ ::=
//~     <left paren> <boolean value expression> <right paren>   -> expr

fn parse_and(left Expr, right Expr) !Expr {
	return BinaryExpr{left, 'AND', right}
}

fn parse_or(left Expr, right Expr) !Expr {
	return BinaryExpr{left, 'OR', right}
}

fn parse_not(expr Expr) !Expr {
	return UnaryExpr{'NOT', expr}
}

fn parse_boolean_test1(e Expr, v Value) !Expr {
	return TruthExpr{e, false, v}
}

fn parse_boolean_test2(e Expr, v Value) !Expr {
	return TruthExpr{e, true, v}
}

fn parse_true() !Value {
	return new_boolean_value(true)
}

fn parse_false() !Value {
	return new_boolean_value(false)
}

fn parse_unknown() !Value {
	return new_unknown_value()
}
