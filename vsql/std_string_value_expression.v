// ISO/IEC 9075-2:2016(E), 6.31, <string value expression>

module vsql

// Format
//~
//~ <string value expression> /* Expr */ ::=
//~     <character value expression>
//~
//~ <character value expression> /* Expr */ ::=
//~     <concatenation>
//~   | <character factor>
//~
//~ <concatenation> /* Expr */ ::=
//~     <character value expression>
//~     <concatenation operator>
//~     <character factor>             -> concatenation
//~
//~ <character factor> /* Expr */ ::=
//~     <character primary>
//~
//~ <character primary> /* Expr */ ::=
//~     <value expression primary>
//~   | <string value function>

fn parse_concatenation(a Expr, b Expr) !Expr {
	return BinaryExpr{a, '||', b}
}
