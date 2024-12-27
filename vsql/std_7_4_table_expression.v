module vsql

// ISO/IEC 9075-2:2016(E), 7.4, <table expression>
//
// Specify a table or a grouped table.

struct TableExpression {
	from_clause  TableReference
	where_clause ?BooleanValueExpression
	group_clause []Identifier
}
