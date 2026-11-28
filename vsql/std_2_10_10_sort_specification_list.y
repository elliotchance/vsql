%%

sort_specification_list:
  sort_specification { $$.v = yy_box([$1.v as SortSpecification]) }
| sort_specification_list comma sort_specification {
    $$.v = yy_append($1.v, $3.v as SortSpecification)
  }

sort_specification:
  sort_key { $$.v = yy_box(new_sort_specification($1.v as ValueExpression, true, none)) }
| sort_key ordering_specification {
    $$.v = yy_box(new_sort_specification($1.v as ValueExpression, $2.v as bool, none))
  }
| sort_key null_ordering {
    $$.v = yy_box(new_sort_specification($1.v as ValueExpression, true, $2.v as bool))
  }
| sort_key ordering_specification null_ordering {
    $$.v = yy_box(new_sort_specification($1.v as ValueExpression, $2.v as bool, $3.v as bool))
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

// The value is true for NULLS FIRST.
//
// ISO/IEC 9075-2:2023, 10.10, <sort specification list>, Conformance Rules, 1
null_ordering:
  NULLS FIRST {
    flag(mut yylex, 'T611')
    $$.v = true
  }
| NULLS LAST {
    flag(mut yylex, 'T611')
    $$.v = false
  }

%%
