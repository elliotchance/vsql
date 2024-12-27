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

query_term:
  query_primary { $$.v = $1.v as SimpleTable }

query_primary:
  simple_table { $$.v = $1.v as SimpleTable }

simple_table:
  query_specification { $$.v = SimpleTable($1.v as QuerySpecification) }
| table_value_constructor { $$.v = $1.v as SimpleTable }

order_by_clause:
  ORDER BY sort_specification_list { $$.v = $3.v }

result_offset_clause:
  OFFSET offset_row_count row_or_rows { $$.v = $2.v }

fetch_first_clause:
  FETCH FIRST fetch_first_quantity row_or_rows ONLY { $$.v = $3.v }

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
