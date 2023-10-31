// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>

module vsql

// Format
//~
//~ <delete statement: searched> /* Stmt */ ::=
//~     DELETE FROM <target table>   -> delete_statement
//~   | DELETE FROM <target table>
//~     WHERE <search condition>     -> delete_statement_where

// DELETE ...
struct DeleteStmt {
	table_name Identifier
	where      ?BooleanValueExpression
}

fn parse_delete_statement(table_name Identifier) !Stmt {
	return DeleteStmt{table_name, none}
}

fn parse_delete_statement_where(table_name Identifier, where BooleanValueExpression) !Stmt {
	return DeleteStmt{table_name, where}
}
