module vsql

// ISO/IEC 9075-2:2016(E), 7.4, <table expression>
//
// # Function
//
// Specify a table or a grouped table.
//
// # Format
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
