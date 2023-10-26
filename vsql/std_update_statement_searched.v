// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>

module vsql

// Format
//~
//~ <update statement: searched> /* Stmt */ ::=
//~     UPDATE <target table>
//~     SET <set clause list>      -> update_statement_searched_1
//~   | UPDATE <target table>
//~     SET <set clause list>
//~     WHERE <search condition>   -> update_statement_searched_2

struct UpdateStatementSearched {
	table_name Identifier
	set        map[string]UpdateSource
	where      ?BooleanValueExpression
}

fn parse_update_statement_searched_1(target_table Identifier, set_clause_list map[string]UpdateSource) !Stmt {
	return UpdateStatementSearched{target_table, set_clause_list, none}
}

fn parse_update_statement_searched_2(target_table Identifier, set_clause_list map[string]UpdateSource, where BooleanValueExpression) !Stmt {
	return UpdateStatementSearched{target_table, set_clause_list, where}
}
