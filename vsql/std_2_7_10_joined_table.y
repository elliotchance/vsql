%%

// ISO/IEC 9075-2:2016(E), 7.10, <joined table>
//
// Specify a table derived from a Cartesian product, inner join, or outer join.
//
// There's no CROSS, NATURAL or FULL (F401), or USING (#777).

joined_table:
  qualified_join { $$.v = $1.v as QualifiedJoin }

join_specification:
  join_condition { $$.v = $1.v as BooleanValueExpression }

join_condition:
  ON search_condition { $$.v = $2.v }

join_type:
  INNER { $$.v = JoinType.inner }
| outer_join_type { $$.v = $1.v as JoinType }
| outer_join_type OUTER { $$.v = $1.v as JoinType }

outer_join_type:
  LEFT { $$.v = JoinType.left }
| RIGHT { $$.v = JoinType.right }

%%
