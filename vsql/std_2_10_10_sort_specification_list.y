%%

sort_specification_list:
  sort_specification { $$.v = [$1.v as SortSpecification] }
| sort_specification_list comma sort_specification {
    $$.v = append_list($1.v as []SortSpecification, $3.v as SortSpecification)
  }

sort_specification:
  sort_key { $$.v = SortSpecification{$1.v as ValueExpression, true} }
| sort_key ordering_specification {
    $$.v = SortSpecification{$1.v as ValueExpression, $2.v as bool}
  }

sort_key:
  value_expression { $$.v = $1.v as ValueExpression }

ordering_specification:
  ASC { $$.v = true }
| DESC { $$.v = false }

%%
