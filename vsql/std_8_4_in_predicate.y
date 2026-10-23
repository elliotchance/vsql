%%

in_predicate:
  row_value_predicand in_predicate_part_2 {
    part := $2.v as InPredicate
    $$.v = InPredicate{
      not:    part.not
      expr:   $1.v as RowValueConstructorPredicand
      values: part.values
    }
  }

in_predicate_part_2:
  IN in_predicate_value {
    $$.v = InPredicate{
      not:    false
      values: $2.v as []RowValueConstructorPredicand
    }
  }
| NOT IN in_predicate_value {
    $$.v = InPredicate{
      not:    true
      values: $3.v as []RowValueConstructorPredicand
    }
  }

in_predicate_value:
  left_paren in_value_list right_paren { $$.v = $2.v }

in_value_list:
  row_value_predicand { $$.v = [$1.v as RowValueConstructorPredicand] }
| in_value_list comma row_value_predicand {
    $$.v = append_list($1.v as []RowValueConstructorPredicand,
      $3.v as RowValueConstructorPredicand)
  }

%%
