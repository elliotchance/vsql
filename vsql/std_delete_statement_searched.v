// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>

module vsql

// Format
//~
//~ <delete statement: searched> /* Stmt */ ::=
//~     DELETE FROM <target table>   -> delete_statement
//~   | DELETE FROM <target table>
//~     WHERE <search condition>     -> delete_statement_where

fn parse_delete_statement(table_name Identifier) !Stmt {
	return DeleteStmt{table_name, NoExpr{}}
}

fn parse_delete_statement_where(table_name Identifier, where Expr) !Stmt {
	return DeleteStmt{table_name, where}
}
