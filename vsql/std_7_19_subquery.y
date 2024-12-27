%%

row_subquery:
  subquery { $$.v = $1.v as QueryExpression }

table_subquery:
  subquery { $$.v = $1.v as TablePrimary }

subquery:
  left_paren query_expression right_paren {
    $$.v = TablePrimary{
      body: $2.v as QueryExpression
    }
  }

%%
