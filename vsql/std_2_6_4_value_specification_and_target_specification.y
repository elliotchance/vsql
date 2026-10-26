%%

value_specification:
  literal { $$.v = ValueSpecification($1.v as Value) }
| general_value_specification {
    $$.v = ValueSpecification($1.v as GeneralValueSpecification)
  }

unsigned_value_specification:
  unsigned_literal { $$.v = ValueSpecification($1.v as Value) }
| general_value_specification {
    $$.v = ValueSpecification($1.v as GeneralValueSpecification)
  }

general_value_specification:
  host_parameter_specification { $$.v = $1.v as GeneralValueSpecification }
| dynamic_parameter_specification {
    $$.v = $1.v as GeneralValueSpecification
  }
| CURRENT_CATALOG { $$.v = GeneralValueSpecification(CurrentCatalog{}) }
| CURRENT_SCHEMA { $$.v = GeneralValueSpecification(CurrentSchema{}) }

simple_value_specification:
  literal { $$.v = ValueSpecification($1.v as Value) }
| host_parameter_name {
    $$.v = ValueSpecification($1.v as GeneralValueSpecification)
  }

host_parameter_specification:
  host_parameter_name { $$.v = $1.v as GeneralValueSpecification }

// A <dynamic parameter specification> is a host parameter named by its
// position, such as "?1" for the first "?" (see tokenize).
dynamic_parameter_specification:
  question_mark {
    $$.v = GeneralValueSpecification(HostParameterName{$1.v as string})
  }

%%
