%%

set_clause_list:
  set_clause { $$.v = $1.v as map[string]UpdateSource }
| set_clause_list comma set_clause {
    $$.v = merge_maps($1.v as map[string]UpdateSource,
      $3.v as map[string]UpdateSource)
  }

set_clause:
  set_target equals_operator update_source {
    $$.v = {
      ($1.v as Identifier).str(): $3.v as UpdateSource
    }
  }

set_target:
  update_target { $$.v = $1.v as Identifier }

update_target:
  object_column { $$.v = $1.v as Identifier }

update_source:
  value_expression { $$.v = UpdateSource($1.v as ValueExpression) }
| contextually_typed_value_specification {
    $$.v = UpdateSource($1.v as NullSpecification)
  }

object_column:
  column_name { $$.v = $1.v as Identifier }

%%
