// ISO/IEC 9075-2:2016(E), 7.4, <table expression>

module vsql

// Format
//~
//~ <table expression> /* TableExpression */ ::=
//~     <from clause>                                    -> table_expression
//~   | <from clause> <where clause>                     -> table_expression_where
//~   | <from clause> <group by clause>                  -> table_expression_group
//~   | <from clause> <where clause> <group by clause>   -> table_expression_where_group

struct TableExpression {
	from_clause  TableReference
	where_clause ?BooleanValueExpression
	group_clause []Identifier
}

fn parse_table_expression(from_clause TableReference) !TableExpression {
	return TableExpression{from_clause, none, []Identifier{}}
}

fn parse_table_expression_group(from_clause TableReference, group []Identifier) !TableExpression {
	return TableExpression{from_clause, none, group}
}

fn parse_table_expression_where(from_clause TableReference, where BooleanValueExpression) !TableExpression {
	return TableExpression{from_clause, where, []Identifier{}}
}

fn parse_table_expression_where_group(from_clause TableReference, where BooleanValueExpression, group []Identifier) !TableExpression {
	return TableExpression{from_clause, where, group}
}
