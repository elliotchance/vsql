%%

// A <row subquery> (F641) isn't supported yet, so a subquery in a row is always
// a <scalar subquery>.
scalar_subquery:
  subquery { $$.v = new_subquery(($1.v as TablePrimary).body as QueryExpression) }

table_subquery:
  subquery { $$.v = $1.v as TablePrimary }

subquery:
  left_paren query_expression right_paren {
    $$.v = TablePrimary{
      body: $2.v as QueryExpression
    }
  }

%%
