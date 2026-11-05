%%

// ISO/IEC 9075-2:2016(E), 7.17, <query expression>
//
// Specify a table.
//
// There's no WITH (T121), INTERSECT (F302), CORRESPONDING (F301), explicit
// table (F661) or FETCH NEXT (#331). LIMIT isn't in the standard, see
// limit_clause.

// A query_expression is either a parenthesized_query_expression or a
// nonparenthesized_query_expression, so that a query_expression in parentheses
// is always parsed the same way (see nonparenthesized_query_expression).
query_expression:
  nonparenthesized_query_expression { $$.v = $1.v as QueryExpression }
| parenthesized_query_expression { $$.v = $1.v as QueryExpression }

query_expression_with_clauses:
  query_expression_body query_expression_clauses {
    $$.v = QueryExpression{
      ...$2.v as QueryExpression
      body: $1.v as SimpleTable
    }
  }

// query_expression_clauses is a QueryExpression that only has the clauses after
// the <query expression body>.
query_expression_clauses:
  order_by_clause {
    $$.v = QueryExpression{
      order: $1.v as []SortSpecification
    }
  }
| result_offset_clause {
    $$.v = QueryExpression{
      offset: $1.v as ValueSpecification
    }
  }
| order_by_clause result_offset_clause {
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }
| fetch_first_clause {
    $$.v = QueryExpression{
      fetch: $1.v as ValueSpecification
    }
  }
| order_by_clause fetch_first_clause {
    $$.v = QueryExpression{
      fetch: $2.v as ValueSpecification
      order: $1.v as []SortSpecification
    }
  }
| order_by_clause result_offset_clause fetch_first_clause {
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }
| result_offset_clause fetch_first_clause {
    $$.v = QueryExpression{
      offset: $1.v as ValueSpecification
      fetch:  $2.v as ValueSpecification
    }
  }
| limit_clause {
    $$.v = QueryExpression{
      fetch: $1.v as ValueSpecification
    }
  }
| order_by_clause limit_clause {
    $$.v = QueryExpression{
      fetch: $2.v as ValueSpecification
      order: $1.v as []SortSpecification
    }
  }
| limit_clause limit_offset_clause {
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $1.v as ValueSpecification
    }
  }
| order_by_clause limit_clause limit_offset_clause {
    $$.v = QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $2.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }
| result_offset_clause limit_clause {
    $$.v = QueryExpression{
      offset: $1.v as ValueSpecification
      fetch:  $2.v as ValueSpecification
    }
  }
| order_by_clause result_offset_clause limit_clause {
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }
| OFFSET offset_row_count limit_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
    }
  }
| order_by_clause OFFSET offset_row_count limit_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    $$.v = QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $4.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }
| OFFSET offset_row_count {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
    }
  }
| order_by_clause OFFSET offset_row_count {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    $$.v = QueryExpression{
      offset: $3.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }
| OFFSET offset_row_count fetch_first_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
    }
  }
| order_by_clause OFFSET offset_row_count fetch_first_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    $$.v = QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $4.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }
| LIMIT fetch_first_row_count comma fetch_first_row_count {
    flag(mut yylex, vsql_limit_offset_count)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    flag_row_count(mut yylex, $4.v as ValueSpecification, 'F860')
    $$.v = QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $4.v as ValueSpecification
    }
  }
| order_by_clause LIMIT fetch_first_row_count comma fetch_first_row_count {
    flag(mut yylex, vsql_limit_offset_count)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    flag_row_count(mut yylex, $5.v as ValueSpecification, 'F860')
    $$.v = QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $5.v as ValueSpecification
      order:  $1.v as []SortSpecification
    }
  }

// nonparenthesized_query_expression is a query_expression that isn't only a
// query_expression in parentheses (a parenthesized_query_expression).
nonparenthesized_query_expression:
  simple_table { $$.v = QueryExpression{body: $1.v as SimpleTable} }
| query_set_operation { $$.v = QueryExpression{body: $1.v as SimpleTable} }
| query_expression_with_clauses { $$.v = $1.v as QueryExpression }

query_expression_body:
  query_term { $$.v = $1.v as SimpleTable }
| query_set_operation { $$.v = $1.v as SimpleTable }

// Without ALL or DISTINCT, it's DISTINCT. DISTINCT is flagged with T551, and
// EXCEPT ALL with F304.
//
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 6
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Conformance Rules, 9 and 10
query_set_operation:
  query_expression_body query_set_operator query_term {
    operator := $2.v as QuerySetOperator
    $$.v = new_set_operation($1.v as SimpleTable, operator.op, operator.all,
      $3.v as SimpleTable)
  }

query_set_operator:
  UNION { $$.v = QuerySetOperator{'UNION', false} }
| UNION set_quantifier {
    flag_if(mut yylex, $2.v as bool, 'T551')
    $$.v = QuerySetOperator{'UNION', !($2.v as bool)}
  }
| EXCEPT { $$.v = QuerySetOperator{'EXCEPT', false} }
| EXCEPT set_quantifier {
    flag(mut yylex, if $2.v as bool { 'T551' } else { 'F304' })
    $$.v = QuerySetOperator{'EXCEPT', !($2.v as bool)}
  }

query_term:
  query_primary { $$.v = $1.v as SimpleTable }

query_primary:
  simple_table { $$.v = $1.v as SimpleTable }
| parenthesized_query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .query_primary)
    $$.v = new_parenthesized_query_expression($1.v as QueryExpression)
  }

// parenthesized_query_expression is a left_paren query_expression right_paren
// of a query_primary or a subquery, so that the parser doesn't need to know
// which one it is until after the right_paren. The inner one of nested
// parentheses is always a query_primary, so that ORDER BY, OFFSET and FETCH in
// it are flagged the same way.
parenthesized_query_expression:
  left_paren nonparenthesized_query_expression right_paren { $$.v = $2.v }
| left_paren parenthesized_query_expression right_paren {
    flag_query_expression(mut yylex, $2.v as QueryExpression, .query_primary)
    $$.v = QueryExpression{
      body: new_parenthesized_query_expression($2.v as QueryExpression)
    }
  }

simple_table:
  query_specification { $$.v = SimpleTable($1.v as QuerySpecification) }
| table_value_constructor {
    // ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Conformance Rules, 5
    flag(mut yylex, 'F661')
    $$.v = $1.v as SimpleTable
  }
| explicit_table {
    flag(mut yylex, 'F661')
    $$.v = SimpleTable($1.v as QuerySpecification)
  }

// "TABLE t" is the same as "SELECT * FROM t" (Syntax Rule 1).
explicit_table:
  TABLE table_or_query_name {
    table_expression := TableExpression{TableReference(TablePrimary{
      body: $2.v as Identifier
    }), none, []Identifier{}, none}
    $$.v = QuerySpecification{
      exprs:            SelectList(AsteriskExpr(true))
      table_expression: &table_expression
    }
  }

order_by_clause:
  ORDER BY sort_specification_list { $$.v = $3.v }

result_offset_clause:
  OFFSET offset_row_count row_or_rows {
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = $2.v
  }

fetch_first_clause:
  FETCH first_or_next fetch_first_quantity row_or_rows ONLY {
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F860')
    $$.v = $3.v
  }
// Without a row count, it's 1.
//
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, General Rules, 7.b.iii
| FETCH first_or_next row_or_rows ONLY { $$.v = ValueSpecification(new_integer_value(1)) }

// LIMIT is a vsql extension that's the same as a fetch_first_clause (V203-01).
// "LIMIT offset, count" is in query_expression_with_clauses (V203-03), since it
// also sets the offset.
limit_clause:
  LIMIT fetch_first_row_count {
    flag(mut yylex, vsql_limit)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F860')
    $$.v = $2.v
  }

// An OFFSET without ROW or ROWS is also a vsql extension (V203-02).
limit_offset_clause:
  result_offset_clause { $$.v = $1.v }
| OFFSET offset_row_count {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = $2.v
  }

first_or_next:
  FIRST
| NEXT

fetch_first_quantity:
  fetch_first_row_count { $$.v = $1.v as ValueSpecification }

offset_row_count:
  simple_value_specification { $$.v = $1.v as ValueSpecification }

fetch_first_row_count:
  simple_value_specification { $$.v = $1.v as ValueSpecification }

row_or_rows:
  ROW
| ROWS

%%
