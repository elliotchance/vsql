%%

sort_specification_list:
  sort_specification { $$.v = yy_box([$1.v as SortSpecification]) }
| sort_specification_list comma sort_specification {
    $$.v = yy_box(append_list($1.v as []SortSpecification, $3.v as SortSpecification))
  }

sort_specification:
  sort_key { $$.v = yy_box(SortSpecification{$1.v as ValueExpression, true}) }
| sort_key ordering_specification {
    $$.v = yy_box(SortSpecification{$1.v as ValueExpression, $2.v as bool})
  }

sort_key:
  sort_key_start value_expression {
    flag_sort_key(mut yylex)
    $$.v = $2.v
  }

sort_key_start:
  { start_sort_key(mut yylex) }

ordering_specification:
  ASC { $$.v = true }
| DESC { $$.v = false }

%%
