%%

// ISO/IEC 9075-2:2016(E), 7.10, <joined table>
//
// Specify a table derived from a Cartesian product, inner join, or outer join.
//
// There's no CROSS, NATURAL or FULL (F401), or join correlation name (F404).

joined_table:
  qualified_join { $$.v = $1.v }

join_specification:
  join_condition { $$.v = yy_box(JoinSpecification($1.v as BooleanValueExpression)) }
| named_columns_join { $$.v = yy_box(JoinSpecification($1.v as []Identifier)) }

join_condition:
  ON search_condition { $$.v = $2.v }

named_columns_join:
  USING left_paren join_column_list right_paren { $$.v = $3.v }

join_column_list:
  column_name_list { $$.v = $1.v }

join_type:
  INNER { $$.v = yy_box(JoinType.inner) }
| outer_join_type { $$.v = $1.v }
| outer_join_type OUTER { $$.v = $1.v }

outer_join_type:
  LEFT { $$.v = yy_box(JoinType.left) }
| RIGHT { $$.v = yy_box(JoinType.right) }

%%
