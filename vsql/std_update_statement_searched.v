// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>

module vsql

// Format
//~
//~ <update statement: searched> /* Stmt */ ::=
//~     UPDATE <target table>
//~     SET <set clause list>      -> update_statement
//~   | UPDATE <target table>
//~     SET <set clause list>
//~     WHERE <search condition>   -> update_statement_where

fn parse_update_statement(target_table Identifier, set_clause_list map[string]Expr) !Stmt {
	return UpdateStmt{target_table, set_clause_list, NoExpr{}}
}

fn parse_update_statement_where(target_table Identifier, set_clause_list map[string]Expr, where Expr) !Stmt {
	return UpdateStmt{target_table, set_clause_list, where}
}
