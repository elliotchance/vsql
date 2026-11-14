%%

// ISO/IEC 9075-2:2023, 8.11, <unique predicate>, Conformance Rules, 1
unique_predicate:
  UNIQUE table_subquery {
    flag(mut yylex, 'F291')
    $$.v = yy_box(UniquePredicate{new_subquery(($2.v as TablePrimary).body as QueryExpression), false})
  }
// ISO/IEC 9075-2:2023, 8.11, <unique predicate>, Conformance Rules, 2
| UNIQUE unique_null_treatment table_subquery {
    flag(mut yylex, 'F291')
    flag(mut yylex, 'F292')
    $$.v = yy_box(UniquePredicate{new_subquery(($3.v as TablePrimary).body as QueryExpression), $2.v as bool})
  }

// unique_null_treatment is true for NULLS NOT DISTINCT.
unique_null_treatment:
  NULLS DISTINCT { $$.v = false }
| NULLS NOT DISTINCT { $$.v = true }

%%
