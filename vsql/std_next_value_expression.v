// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>

module vsql

// Format
//~
//~ <next value expression> /* Expr */ ::=
//~     NEXT VALUE FOR <sequence generator name>   -> next_value_expression

fn parse_next_value_expression(name Identifier) !Expr {
	return NextValueExpr{
		name: name
	}
}
