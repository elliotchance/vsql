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
//~ <result offset clause> /* Expr */ ::=
//~     OFFSET <offset row count> <row or rows>   -> expr
//~
//~ <fetch first clause> /* Expr */ ::=
//~     FETCH FIRST
//~     <fetch first quantity>
//~     <row or rows>
//~     ONLY                     -> fetch_first_clause
//~
//~ <fetch first quantity> /* Expr */ ::=
//~     <fetch first row count>
//~
//~ <offset row count> /* Expr */ ::=
//~     <simple value specification>
//~
//~ <fetch first row count> /* Expr */ ::=
//~     <simple value specification>
//
// These are non-standard, just to simplify standard rules:
//~
//~ <row or rows> ::=
//~     ROW
//~   | ROWS

fn parse_query_expression(body SimpleTable) !QueryExpression {
	return QueryExpression{
		body: body
		offset: NoExpr{}
		fetch: NoExpr{}
	}
}

fn parse_query_expression_order(body SimpleTable, order []SortSpecification) !QueryExpression {
	return QueryExpression{
		body: body
		offset: NoExpr{}
		fetch: NoExpr{}
		order: order
	}
}

fn parse_query_expression_offset(body SimpleTable, offset Expr) !QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		fetch: NoExpr{}
	}
}

fn parse_query_expression_order_offset(body SimpleTable, order []SortSpecification, offset Expr) !QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		fetch: NoExpr{}
		order: order
	}
}

fn parse_query_expression_fetch(body SimpleTable, fetch Expr) !QueryExpression {
	return QueryExpression{
		body: body
		offset: NoExpr{}
		fetch: fetch
	}
}

fn parse_query_expression_order_fetch(body SimpleTable, order []SortSpecification, fetch Expr) !QueryExpression {
	return QueryExpression{
		body: body
		offset: NoExpr{}
		fetch: fetch
		order: order
	}
}

fn parse_query_expression_offset_fetch(body SimpleTable, offset Expr, fetch Expr) !QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		fetch: fetch
	}
}

fn parse_query_expression_order_offset_fetch(body SimpleTable, order []SortSpecification, offset Expr, fetch Expr) !QueryExpression {
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

fn parse_fetch_first_clause(quantity Expr) !Expr {
	return quantity
}
