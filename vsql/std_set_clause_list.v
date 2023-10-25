// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>

module vsql

// Format
//~
//~ <set clause list> /* map[string]Expr */ ::=
//~     <set clause>
//~   | <set clause list> <comma> <set clause>   -> set_clause_append
//~
//~ <set clause> /* map[string]Expr */ ::=
//~   <set target> <equals operator> <update source>   -> set_clause
//~
//~ <set target> /* Identifier */ ::=
//~     <update target>
//~
//~ <update target> /* Identifier */ ::=
//~     <object column>
//~
//~ <update source> /* Expr */ ::=
//~     <value expression>
//~   | <contextually typed value specification>
//~
//~ <object column> /* Identifier */ ::=
//~     <column name>

fn parse_set_clause_append(set_clause_list map[string]Expr, set_clause map[string]Expr) !map[string]Expr {
	mut new_set_clause_list := set_clause_list.clone()

	// Even though there will only be one of these.
	for k, v in set_clause {
		new_set_clause_list[k] = v
	}

	return new_set_clause_list
}

fn parse_set_clause(target Identifier, update_source Expr) !map[string]Expr {
	return {
		target.str(): update_source
	}
}
