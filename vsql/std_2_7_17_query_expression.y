%%

// ISO/IEC 9075-2:2023, 7.17, <query expression>
//
// Specify a table.
//
// There's no WITH (T121), CORRESPONDING (F301) or FETCH
// NEXT (#331). LIMIT isn't in the standard, see limit_clause.

// A query_expression is either a parenthesized_query_expression or a
// nonparenthesized_query_expression, so that a query_expression in parentheses
// is always parsed the same way (see nonparenthesized_query_expression).
query_expression:
  nonparenthesized_query_expression { $$.v = $1.v }
| parenthesized_query_expression { $$.v = $1.v }

query_expression_with_clauses:
  query_expression_body query_expression_clauses {
    $$.v = yy_box(QueryExpression{
      ...$2.v as QueryExpression
      body: $1.v as SimpleTable
    })
  }

// query_expression_clauses is a QueryExpression that only has the clauses after
// the <query expression body>.
query_expression_clauses:
  order_by_clause {
    $$.v = yy_box(QueryExpression{
      order: $1.v as []SortSpecification
    })
  }
| result_offset_clause {
    $$.v = yy_box(QueryExpression{
      offset: $1.v as ValueSpecification
    })
  }
| order_by_clause result_offset_clause {
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }
| fetch_first_clause {
    $$.v = yy_box(QueryExpression{
      fetch: $1.v as ValueSpecification
    })
  }
| order_by_clause fetch_first_clause {
    $$.v = yy_box(QueryExpression{
      fetch: $2.v as ValueSpecification
      order: $1.v as []SortSpecification
    })
  }
| order_by_clause result_offset_clause fetch_first_clause {
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }
| result_offset_clause fetch_first_clause {
    $$.v = yy_box(QueryExpression{
      offset: $1.v as ValueSpecification
      fetch:  $2.v as ValueSpecification
    })
  }
| limit_clause {
    $$.v = yy_box(QueryExpression{
      fetch: $1.v as ValueSpecification
    })
  }
| order_by_clause limit_clause {
    $$.v = yy_box(QueryExpression{
      fetch: $2.v as ValueSpecification
      order: $1.v as []SortSpecification
    })
  }
| limit_clause limit_offset_clause {
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $1.v as ValueSpecification
    })
  }
| order_by_clause limit_clause limit_offset_clause {
    $$.v = yy_box(QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $2.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }
| result_offset_clause limit_clause {
    $$.v = yy_box(QueryExpression{
      offset: $1.v as ValueSpecification
      fetch:  $2.v as ValueSpecification
    })
  }
| order_by_clause result_offset_clause limit_clause {
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }
| OFFSET offset_row_count limit_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
    })
  }
| order_by_clause OFFSET offset_row_count limit_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    $$.v = yy_box(QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $4.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }
| OFFSET offset_row_count {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
    })
  }
| order_by_clause OFFSET offset_row_count {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    $$.v = yy_box(QueryExpression{
      offset: $3.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }
| OFFSET offset_row_count fetch_first_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
    })
  }
| order_by_clause OFFSET offset_row_count fetch_first_clause {
    flag(mut yylex, vsql_offset_without_rows)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    $$.v = yy_box(QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $4.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }
| LIMIT fetch_first_row_count comma fetch_first_row_count {
    flag(mut yylex, vsql_limit_offset_count)
    flag_row_count(mut yylex, $2.v as ValueSpecification, 'F865')
    flag_row_count(mut yylex, $4.v as ValueSpecification, 'F860')
    $$.v = yy_box(QueryExpression{
      offset: $2.v as ValueSpecification
      fetch:  $4.v as ValueSpecification
    })
  }
| order_by_clause LIMIT fetch_first_row_count comma fetch_first_row_count {
    flag(mut yylex, vsql_limit_offset_count)
    flag_row_count(mut yylex, $3.v as ValueSpecification, 'F865')
    flag_row_count(mut yylex, $5.v as ValueSpecification, 'F860')
    $$.v = yy_box(QueryExpression{
      offset: $3.v as ValueSpecification
      fetch:  $5.v as ValueSpecification
      order:  $1.v as []SortSpecification
    })
  }

// nonparenthesized_query_expression is a query_expression that isn't only a
// query_expression in parentheses (a parenthesized_query_expression).
nonparenthesized_query_expression:
  simple_table { $$.v = yy_box(QueryExpression{body: $1.v as SimpleTable}) }
| query_set_operation { $$.v = yy_box(QueryExpression{body: $1.v as SimpleTable}) }
| query_intersect_operation { $$.v = yy_box(QueryExpression{body: $1.v as SimpleTable}) }
| query_expression_with_clauses { $$.v = $1.v }

query_expression_body:
  query_term { $$.v = $1.v }
| query_set_operation { $$.v = $1.v }

// Without ALL or DISTINCT, it's DISTINCT. DISTINCT is flagged with T551, and
// EXCEPT ALL with F304.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 6
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Conformance Rules, 10 and 11
query_set_operation:
  query_expression_body query_set_operator query_term {
    operator := $2.v as QuerySetOperator
    $$.v = yy_box(new_set_operation($1.v as SimpleTable, operator.op, operator.all,
      $3.v as SimpleTable))
  }

query_set_operator:
  UNION { $$.v = yy_box(QuerySetOperator{'UNION', false}) }
| UNION set_quantifier {
    flag_if(mut yylex, $2.v as bool, 'T551')
    $$.v = yy_box(QuerySetOperator{'UNION', !($2.v as bool)})
  }
| EXCEPT { $$.v = yy_box(QuerySetOperator{'EXCEPT', false}) }
| EXCEPT set_quantifier {
    flag(mut yylex, if $2.v as bool { 'T551' } else { 'F304' })
    $$.v = yy_box(QuerySetOperator{'EXCEPT', !($2.v as bool)})
  }

query_term:
  query_primary { $$.v = $1.v }
| query_intersect_operation { $$.v = $1.v }

// INTERSECT is a query_term, so it's evaluated before a UNION or EXCEPT on
// either side of it. "a UNION b INTERSECT c" is "a UNION (b INTERSECT c)".
query_intersect_operation:
  query_term intersect_operator query_primary {
    operator := $2.v as QuerySetOperator
    $$.v = yy_box(new_set_operation($1.v as SimpleTable, operator.op, operator.all,
      $3.v as SimpleTable))
  }

// Without ALL or DISTINCT, it's DISTINCT. INTERSECT is flagged with F303,
// INTERSECT ALL also with F305 and INTERSECT DISTINCT also with T551.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 6
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Conformance Rules, 7, 8 and 10
intersect_operator:
  INTERSECT {
    flag(mut yylex, 'F303')
    $$.v = yy_box(QuerySetOperator{'INTERSECT', false})
  }
| INTERSECT set_quantifier {
    flag(mut yylex, 'F303')
    flag_if(mut yylex, !($2.v as bool), 'F305')
    flag_if(mut yylex, $2.v as bool, 'T551')
    $$.v = yy_box(QuerySetOperator{'INTERSECT', !($2.v as bool)})
  }

query_primary:
  simple_table { $$.v = $1.v }
| parenthesized_query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .query_primary)
    $$.v = yy_box(new_parenthesized_query_expression($1.v as QueryExpression))
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
    $$.v = yy_box(QueryExpression{
      body: new_parenthesized_query_expression($2.v as QueryExpression)
    })
  }

simple_table:
  query_specification { $$.v = yy_box(SimpleTable($1.v as QuerySpecification)) }
| table_value_constructor {
    // ISO/IEC 9075-2:2023, 7.17, <query expression>, Conformance Rules, 5
    flag(mut yylex, 'F661')
    $$.v = $1.v
  }
| explicit_table {
    // ISO/IEC 9075-2:2023, 7.17, <query expression>, Conformance Rules, 6
    flag(mut yylex, 'F661')
    $$.v = yy_box(SimpleTable($1.v as QuerySpecification))
  }

// "TABLE t" is the same as "SELECT * FROM t", so its columns are the columns of
// the table.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 4
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 13.b
explicit_table:
  TABLE table_or_query_name {
    table_expression := TableExpression{TableReference(TablePrimary{
      body: $2.v as Identifier
    }), none, []Identifier{}, none}
    $$.v = yy_box(QuerySpecification{
      exprs:            SelectList(AsteriskExpr(true))
      table_expression: &table_expression
    })
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
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 7.b.iii
| FETCH first_or_next row_or_rows ONLY { $$.v = yy_box(ValueSpecification(new_integer_value(1))) }

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
  fetch_first_row_count { $$.v = $1.v }

offset_row_count:
  simple_value_specification { $$.v = $1.v }

fetch_first_row_count:
  simple_value_specification { $$.v = $1.v }

row_or_rows:
  ROW
| ROWS

%%
