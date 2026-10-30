%%

query_expression:
  query_expression_body { $$.v = QueryExpression{body: $1.v as SimpleTable} }
| query_expression_body order_by_clause { 
    $$.v = QueryExpression{
      body:  $1.v as SimpleTable
      order: $2.v as []SortSpecification
    }
  }
| query_expression_body result_offset_clause {
    $$.v = QueryExpression{
      body:   $1.v as SimpleTable
      offset: $2.v as ValueSpecification
    }
  }
| query_expression_body order_by_clause result_offset_clause {
    $$.v = QueryExpression{
      body:   $1.v as SimpleTable
      offset: $3.v as ValueSpecification
      order:  $2.v as []SortSpecification
    }
  }
| query_expression_body fetch_first_clause {
    $$.v = QueryExpression{
      body:  $1.v as SimpleTable
      fetch: $2.v as ValueSpecification
    }
  }
| query_expression_body order_by_clause fetch_first_clause {
    $$.v = QueryExpression{
      body:  $1.v as SimpleTable
      fetch: $3.v as ValueSpecification
      order: $2.v as []SortSpecification
    }
  }
| query_expression_body order_by_clause result_offset_clause
  fetch_first_clause {
    $$.v = QueryExpression{
      body:   $1.v as SimpleTable
      offset: $3.v as ValueSpecification
      fetch:  $4.v as ValueSpecification
      order:  $2.v as []SortSpecification
    }
  }
| query_expression_body result_offset_clause fetch_first_clause {
    $$.v = QueryExpression{
      body:   $1.v as SimpleTable
      offset: $2.v as ValueSpecification
      fetch:  $3.v as ValueSpecification
    }
  }

query_expression_body:
  query_term { $$.v = $1.v as SimpleTable }
| query_expression_body UNION query_term {
    $$.v = new_set_operation($1.v as SimpleTable, 'UNION', false,
      $3.v as SimpleTable)
  }
| query_expression_body UNION set_quantifier query_term {
    flag_if(mut yylex, $3.v as bool, 'T551')
    $$.v = new_set_operation($1.v as SimpleTable, 'UNION', !($3.v as bool),
      $4.v as SimpleTable)
  }
| query_expression_body EXCEPT query_term {
    $$.v = new_set_operation($1.v as SimpleTable, 'EXCEPT', false,
      $3.v as SimpleTable)
  }
| query_expression_body EXCEPT set_quantifier query_term {
    flag(mut yylex, if $3.v as bool { 'T551' } else { 'F304' })
    $$.v = new_set_operation($1.v as SimpleTable, 'EXCEPT', !($3.v as bool),
      $4.v as SimpleTable)
  }

query_term:
  query_primary { $$.v = $1.v as SimpleTable }

query_primary:
  simple_table { $$.v = $1.v as SimpleTable }
| left_paren query_expression right_paren {
    flag_query_expression(mut yylex, $2.v as QueryExpression, .query_primary)
    $$.v = new_parenthesized_query_expression($2.v as QueryExpression)
  }

simple_table:
  query_specification { $$.v = SimpleTable($1.v as QuerySpecification) }
| table_value_constructor {
    flag(mut yylex, 'F661')
    $$.v = $1.v as SimpleTable
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
| FETCH first_or_next row_or_rows ONLY { $$.v = ValueSpecification(new_integer_value(1)) }

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
