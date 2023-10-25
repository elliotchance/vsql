// ISO/IEC 9075-2:2016(E), 7.13, <group by clause>

module vsql

// Format
//~
//~ <group by clause> /* []Expr */ ::=
//~     GROUP BY <grouping element list>   -> exprs
//~
//~ <grouping element list> /* []Expr */ ::=
//~     <grouping element>                                   -> expr_to_list
//~   | <grouping element list> <comma> <grouping element>   -> append_exprs1
//~
//~ <grouping element> /* Expr */ ::=
//~     <ordinary grouping set>
//~
//~ <ordinary grouping set> /* Expr */ ::=
//~     <grouping column reference>
//~
//~ <grouping column reference> /* Expr */ ::=
//~     <column reference>   -> identifier_to_expr

fn parse_exprs(e []Expr) ![]Expr {
	return e
}
