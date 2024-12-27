%%

joined_table:
  qualified_join { $$.v = $1.v as QualifiedJoin }

join_specification:
  join_condition { $$.v = $1.v as BooleanValueExpression }

join_condition:
  ON search_condition { $$.v = $2.v }

join_type:
  INNER
| outer_join_type { $$.v = $1.v as string }
| outer_join_type OUTER { $$.v = $1.v as string }

outer_join_type:
  LEFT { $$.v = $1.v as string }
| RIGHT { $$.v = $1.v as string }

%%
