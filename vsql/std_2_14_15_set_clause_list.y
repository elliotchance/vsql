%%

// ISO/IEC 9075-2:2023(E), 14.15, <set clause list>
//
// Specify a list of updates.

set_clause_list:
  set_clause { $$.v = yy_box([$1.v as SetClause]) }
| set_clause_list comma set_clause {
    $$.v = yy_box(append_list($1.v as []SetClause, $3.v as SetClause))
  }

set_clause:
  set_target equals_operator update_source {
    $$.v = yy_box(SetClause{($1.v as Identifier).sub_entity_name, $3.v as UpdateSource})
  }

set_target:
  update_target { $$.v = $1.v }

update_target:
  object_column { $$.v = $1.v }

update_source:
  value_expression { $$.v = yy_box(UpdateSource($1.v as ValueExpression)) }
| contextually_typed_value_specification {
    $$.v = yy_box(UpdateSource($1.v as ContextuallyTypedValueSpecification))
  }

object_column:
  column_name { $$.v = $1.v }

%%
