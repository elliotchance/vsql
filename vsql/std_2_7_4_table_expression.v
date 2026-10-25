module vsql

// ISO/IEC 9075-2:2016(E), 7.4, <table expression>
//
// Specify a table or a grouped table.

struct TableExpression {
	from_clause   TableReference
	where_clause  ?BooleanValueExpression
	group_clause  []Identifier
	having_clause ?BooleanValueExpression
}

fn (e TableExpression) pstr(params map[string]Value) string {
	mut s := 'FROM ${e.from_clause.pstr(params)}'

	if where := e.where_clause {
		s += ' WHERE ${where.pstr(params)}'
	}

	if e.group_clause.len > 0 {
		mut columns := []string{}
		for column in e.group_clause {
			columns << column.str()
		}
		s += ' GROUP BY ${columns.join(', ')}'
	}

	if having := e.having_clause {
		s += ' HAVING ${having.pstr(params)}'
	}

	return s
}
