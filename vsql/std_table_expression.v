// ISO/IEC 9075-2:2016(E), 7.4, <table expression>

module vsql

// Format
//~
//~ <table expression> /* TableExpression */ ::=
//~     <from clause>                                    -> table_expression
//~   | <from clause> <where clause>                     -> table_expression_where
//~   | <from clause> <group by clause>                  -> table_expression_group
//~   | <from clause> <where clause> <group by clause>   -> table_expression_where_group

fn parse_table_expression(from_clause TableReference) !TableExpression {
	return TableExpression{from_clause, NoExpr{}, []Expr{}}
}

fn parse_table_expression_group(from_clause TableReference, group []Expr) !TableExpression {
	return TableExpression{from_clause, NoExpr{}, group}
}

fn parse_table_expression_where(from_clause TableReference, where Expr) !TableExpression {
	return TableExpression{from_clause, where, []Expr{}}
}

fn parse_table_expression_where_group(from_clause TableReference, where Expr, group []Expr) !TableExpression {
	return TableExpression{from_clause, where, group}
}
