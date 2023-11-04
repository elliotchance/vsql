module vsql

// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>
//
// # Function
//
// Specify a list of updates.
//
// # Format
//~
//~ <set clause list> /* map[string]UpdateSource */ ::=
//~     <set clause>
//~   | <set clause list> <comma> <set clause>   -> set_clause_append
//~
//~ <set clause> /* map[string]UpdateSource */ ::=
//~   <set target> <equals operator> <update source>   -> set_clause
//~
//~ <set target> /* Identifier */ ::=
//~     <update target>
//~
//~ <update target> /* Identifier */ ::=
//~     <object column>
//~
//~ <update source> /* UpdateSource */ ::=
//~     <value expression>                         -> UpdateSource
//~   | <contextually typed value specification>   -> UpdateSource
//~
//~ <object column> /* Identifier */ ::=
//~     <column name>

type UpdateSource = NullSpecification | ValueExpression

fn (e UpdateSource) pstr(params map[string]Value) string {
	return match e {
		ValueExpression, NullSpecification {
			e.pstr(params)
		}
	}
}

fn (e UpdateSource) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, NullSpecification {
			return e.compile(mut c)!
		}
	}
}

fn parse_set_clause_append(set_clause_list map[string]UpdateSource, set_clause map[string]UpdateSource) !map[string]UpdateSource {
	mut new_set_clause_list := set_clause_list.clone()

	// Even though there will only be one of these.
	for k, v in set_clause {
		new_set_clause_list[k] = v
	}

	return new_set_clause_list
}

fn parse_set_clause(target Identifier, update_source UpdateSource) !map[string]UpdateSource {
	return {
		target.str(): update_source
	}
}
