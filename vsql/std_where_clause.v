// ISO/IEC 9075-2:2016(E), 7.12, <where clause>

module vsql

// Format
//~
//~ <where clause> /* BooleanValueExpression */ ::=
//~     WHERE <search condition>   -> where_clause

fn parse_where_clause(b BooleanValueExpression) !BooleanValueExpression {
	return b
}
