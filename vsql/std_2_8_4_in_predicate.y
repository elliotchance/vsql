%%

in_predicate:
  row_value_predicand in_predicate_part_2 {
    part := $2.v as InPredicate
    $$.v = InPredicate{
      ...part
      expr: $1.v as RowValueConstructorPredicand
    }
  }

in_predicate_part_2:
  IN in_predicate_value { $$.v = $2.v as InPredicate }
| NOT IN in_predicate_value {
    part := $3.v as InPredicate
    $$.v = InPredicate{
      ...part
      not: true
    }
  }

in_predicate_value:
  table_subquery {
    $$.v = InPredicate{
      subquery: new_subquery(($1.v as TablePrimary).body as QueryExpression)
    }
  }
| left_paren in_value_list right_paren {
    // ISO/IEC 9075-2:2016(E), 8.4, <in predicate>, Conformance Rules, 1
    flag_if(mut yylex, ($2.v as []RowValueConstructorPredicand).any(!is_value_specification(it)),
      'F561')
    $$.v = InPredicate{
      values: $2.v as []RowValueConstructorPredicand
    }
  }

in_value_list:
  row_value_predicand { $$.v = [$1.v as RowValueConstructorPredicand] }
| in_value_list comma row_value_predicand {
    $$.v = append_list($1.v as []RowValueConstructorPredicand,
      $3.v as RowValueConstructorPredicand)
  }

%%
