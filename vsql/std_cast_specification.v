// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>

module vsql

// Format
//~
//~ <cast specification> /* Expr */ ::=
//~     CAST <left paren> <cast operand> AS <cast target> <right paren>   -> cast
//~
//~ <cast operand> /* Expr */ ::=
//~     <value expression>
//~   | <implicitly typed value specification>
//~
//~ <cast target> /* Type */ ::=
//~     <data type>

fn parse_cast(expr Expr, typ Type) !Expr {
	return CastExpr{expr, typ}
}
