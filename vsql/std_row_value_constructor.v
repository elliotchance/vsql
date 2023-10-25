// ISO/IEC 9075-2:2016(E), 7.1, <row value constructor>

module vsql

// Format
//~
//~ <row value constructor> /* Expr */ ::=
//~     <common value expression>
//~   | <boolean value expression>
//~   | <explicit row value constructor>
//~
//~ <explicit row value constructor> /* Expr */ ::=
//~     ROW <left paren> <row value constructor element list>
//~     <right paren>                                           -> row_constructor1
//~   | <row subquery>                                          -> row_constructor2
//~
//~ <row value constructor element list> /* []Expr */ ::=
//~     <row value constructor element>                -> expr_to_list
//~   | <row value constructor element list> <comma>
//~     <row value constructor element>                -> append_exprs1
//~
//~ <row value constructor element> /* Expr */ ::=
//~     <value expression>
//~
//~ <contextually typed row value constructor> /* []Expr */ ::=
//~     <common value expression>                        -> expr_to_list
//~   | <boolean value expression>                       -> expr_to_list
//~   | <contextually typed value specification>         -> expr_to_list
//~   | <left paren> <contextually typed value specification>
//~     <right paren>                                    -> expr_to_list
//~   | <left paren>
//~     <contextually typed row value constructor element> <comma>
//~     <contextually typed row value constructor element list>
//~     <right paren>                                    -> append_exprs2
//~
//~ <contextually typed row value constructor element list> /* []Expr */ ::=
//~     <contextually typed row value constructor element>        -> expr_to_list
//~   | <contextually typed row value constructor element list>
//~     <comma>
//~     <contextually typed row value constructor element>        -> append_exprs1
//~
//~ <contextually typed row value constructor element> /* Expr */ ::=
//~     <value expression>
//~   | <contextually typed value specification>
//~
//~ <row value constructor predicand> /* Expr */ ::=
//~     <common value expression>
//~   | <boolean predicand>

fn parse_row_constructor1(exprs []Expr) !Expr {
	return RowExpr{exprs}
}

fn parse_row_constructor2(expr QueryExpression) !Expr {
	return expr
}

fn parse_append_exprs2(element Expr, element_list []Expr) ![]Expr {
	mut new_list := []Expr{}
	new_list << element
	for e in element_list {
		new_list << e
	}

	return new_list
}
