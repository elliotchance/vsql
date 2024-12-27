module vsql

// ISO/IEC 9075-2:2016(E), 7.12, <where clause>
//
// # Function
//
// Specify a table derived by the application of a <search condition> to the
// result of the preceding <from clause>.
//
// # Format
//~
//~ <where clause> /* BooleanValueExpression */ ::=
//~     WHERE <search condition>   -> where_clause

fn parse_where_clause(b BooleanValueExpression) !BooleanValueExpression {
	return b
}
