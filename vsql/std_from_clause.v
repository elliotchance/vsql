// ISO/IEC 9075-2:2016(E), 7.5, <from clause>

module vsql

// Format
//~
//~ <from clause> /* TableReference */ ::=
//~     FROM <table reference list>   -> from_clause
//~
//~ <table reference list> /* TableReference */ ::=
//~     <table reference>

fn parse_from_clause(table TableReference) !TableReference {
	return table
}
