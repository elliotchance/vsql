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
