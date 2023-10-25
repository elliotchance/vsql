// ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>

module vsql

// Format
//~
//~ <numeric value expression> /* Expr */ ::=
//~     <term>
//~   | <numeric value expression> <plus sign> <term>    -> binary_expr
//~   | <numeric value expression> <minus sign> <term>   -> binary_expr
//~
//~ <term> /* Expr */ ::=
//~     <factor>
//~   | <term> <asterisk> <factor>   -> binary_expr
//~   | <term> <solidus> <factor>    -> binary_expr
//~
//~ <factor> /* Expr */ ::=
//~     <numeric primary>
//~   | <sign> <numeric primary>   -> sign_expr
//~
//~ <numeric primary> /* Expr */ ::=
//~     <value expression primary>
//~   | <numeric value function>

fn parse_binary_expr(left Expr, op string, right Expr) !Expr {
	return BinaryExpr{left, op, right}
}

fn parse_sign_expr(sign string, expr Expr) !Expr {
	if sign == '-' {
		return UnaryExpr{'-', expr}
	}

	return expr
}
