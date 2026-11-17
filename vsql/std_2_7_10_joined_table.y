%%

// ISO/IEC 9075-2:2023, 7.10, <joined table>
//
// Specify a table derived from a Cartesian product, inner join, or outer join.
//
// There's no FULL (F406), or join correlation name (F404).

joined_table:
  cross_join { $$.v = $1.v }
| qualified_join { $$.v = $1.v }
| natural_join { $$.v = $1.v }

// A CROSS JOIN is the same as a comma in FROM, so it's an inner join on TRUE.
// The right side can't be a joined table without parentheses.
//
// ISO/IEC 9075-2:2023, 7.10, <joined table>, General Rules, 1.a
cross_join:
  table_reference CROSS JOIN table_factor {
    // ISO/IEC 9075-2:2023, 7.10, <joined table>, Conformance Rules, 1
    flag(mut yylex, 'F407')
    $$.v = yy_box(new_cross_join($1.v as TableReference,
      TableReference($4.v as TablePrimary)))
  }
| table_reference CROSS JOIN parenthesized_joined_table {
    // ISO/IEC 9075-2:2023, 7.10, <joined table>, Conformance Rules, 1
    flag(mut yylex, 'F407')
    $$.v = yy_box(new_cross_join($1.v as TableReference,
      TableReference($4.v as QualifiedJoin)))
  }

// A NATURAL join is a USING of every column name that's on both sides. Like a
// CROSS JOIN, the right side can't be a joined table without parentheses.
//
// ISO/IEC 9075-2:2023, 7.10, <joined table>, Syntax Rules, 5 and 10.b
natural_join:
  table_reference NATURAL JOIN natural_join_right {
    // ISO/IEC 9075-2:2023, 7.10, <joined table>, Conformance Rules, 2
    flag(mut yylex, 'F405')
    $$.v = yy_box(new_qualified_join($1.v as TableReference, JoinType.inner,
      $4.v as TableReference, NaturalJoin{}))
  }
| table_reference NATURAL join_type JOIN natural_join_right {
    // ISO/IEC 9075-2:2023, 7.10, <joined table>, Conformance Rules, 2
    flag(mut yylex, 'F405')
    $$.v = yy_box(new_qualified_join($1.v as TableReference, $3.v as JoinType,
      $5.v as TableReference, NaturalJoin{}))
  }

natural_join_right:
  table_factor { $$.v = yy_box(TableReference($1.v as TablePrimary)) }
| parenthesized_joined_table {
    $$.v = yy_box(TableReference($1.v as QualifiedJoin))
  }

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
