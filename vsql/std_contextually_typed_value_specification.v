// ISO/IEC 9075-2:2016(E), 6.5, <contextually typed value specification>

module vsql

// Format
//~
//~ <contextually typed value specification> /* Expr */ ::=
//~     <implicitly typed value specification>
//~
//~ <implicitly typed value specification> /* Expr */ ::=
//~     <null specification>
//~
//~ <null specification> /* Expr */ ::=
//~     NULL   -> null

fn parse_null() !Expr {
	return UntypedNullExpr{}
}
