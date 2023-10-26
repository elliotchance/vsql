// ISO/IEC 9075-2:2016(E), 7.17, <query expression>

module vsql

// Format
//~
//~ <query expression> /* QueryExpression */ ::=
//~     <query expression body>                     -> query_expression
//~   | <query expression body> <order by clause>   -> query_expression_order
//~   | <query expression body>
//~     <result offset clause>                      -> query_expression_offset
//~   | <query expression body> <order by clause>
//~     <result offset clause>                      -> query_expression_order_offset
//~   | <query expression body>
//~     <fetch first clause>                        -> query_expression_fetch
//~   | <query expression body> <order by clause>
//~     <fetch first clause>                        -> query_expression_order_fetch
//~   | <query expression body> <order by clause>
//~     <result offset clause>
//~     <fetch first clause>                        -> query_expression_order_offset_fetch
//~   | <query expression body>
//~     <result offset clause>
//~     <fetch first clause>                        -> query_expression_offset_fetch
//~
//~ <query expression body> /* SimpleTable */ ::=
//~     <query term>
//~
//~ <query term> /* SimpleTable */ ::=
//~     <query primary>
//~
//~ <query primary> /* SimpleTable */ ::=
//~     <simple table>
//~
//~ <simple table> /* SimpleTable */ ::=
//~     <query specification>
//~   | <table value constructor>
//~
//~ <order by clause> /* []SortSpecification */ ::=
//~     ORDER BY <sort specification list>   -> order_by
//~
//~ <result offset clause> /* ValueSpecification */ ::=
//~     OFFSET <offset row count> <row or rows>   -> result_offset_clause
//~
//~ <fetch first clause> /* ValueSpecification */ ::=
//~     FETCH FIRST
//~     <fetch first quantity>
//~     <row or rows>
//~     ONLY                     -> fetch_first_clause
//~
//~ <fetch first quantity> /* ValueSpecification */ ::=
//~     <fetch first row count>
//~
//~ <offset row count> /* ValueSpecification */ ::=
//~     <simple value specification>
//~
//~ <fetch first row count> /* ValueSpecification */ ::=
//~     <simple value specification>
//
// These are non-standard, just to simplify standard rules:
//~
//~ <row or rows> ::=
//~     ROW
//~   | ROWS

struct QueryExpression {
	body   SimpleTable
	fetch  ?ValueSpecification
	offset ?ValueSpecification
	order  []SortSpecification
}

fn (e QueryExpression) pstr(params map[string]Value) string {
	return '<subquery>'
}

fn parse_query_expression(body SimpleTable) !QueryExpression {
	return QueryExpression{
		body: body
	}
}

fn parse_query_expression_order(body SimpleTable, order []SortSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		order: order
	}
}

fn parse_query_expression_offset(body SimpleTable, offset ValueSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
	}
}

fn parse_query_expression_order_offset(body SimpleTable, order []SortSpecification, offset ValueSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		order: order
	}
}

fn parse_query_expression_fetch(body SimpleTable, fetch ValueSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		fetch: fetch
	}
}

fn parse_query_expression_order_fetch(body SimpleTable, order []SortSpecification, fetch ValueSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		fetch: fetch
		order: order
	}
}

fn parse_query_expression_offset_fetch(body SimpleTable, offset ValueSpecification, fetch ValueSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		fetch: fetch
	}
}

fn parse_query_expression_order_offset_fetch(body SimpleTable, order []SortSpecification, offset ValueSpecification, fetch ValueSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		fetch: fetch
		order: order
	}
}

fn parse_order_by(specs []SortSpecification) ![]SortSpecification {
	return specs
}

fn parse_fetch_first_clause(v ValueSpecification) !ValueSpecification {
	return v
}

fn parse_result_offset_clause(v ValueSpecification) !ValueSpecification {
	return v
}
