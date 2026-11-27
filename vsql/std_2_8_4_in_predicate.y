%%

in_predicate:
  row_value_predicand in_predicate_part_2 {
    part := $2.v as InPredicate
    $$.v = yy_box(InPredicate{
      ...part
      expr: $1.v as RowValueConstructorPredicand
    })
  }

in_predicate_part_2:
  IN in_predicate_value { $$.v = $2.v }
| NOT IN in_predicate_value {
    part := $3.v as InPredicate
    $$.v = yy_box(InPredicate{
      ...part
      not: true
    })
  }

in_predicate_value:
  table_subquery {
    $$.v = yy_box(InPredicate{
      subquery: new_subquery(($1.v as TablePrimary).body as QueryExpression)
    })
  }
| left_paren in_value_list right_paren {
    // ISO/IEC 9075-2:2023, 8.4, <in predicate>, Conformance Rules, 1
    flag_if(mut yylex, !all_value_specifications($2.v as []RowValueConstructorPredicand),
      'F561')
    $$.v = yy_box(InPredicate{
      values: $2.v as []RowValueConstructorPredicand
    })
  }

in_value_list:
  row_value_predicand { $$.v = yy_box([$1.v as RowValueConstructorPredicand]) }
| in_value_list comma row_value_predicand {
    $$.v = yy_append($1.v, $3.v as RowValueConstructorPredicand)
  }

%%
