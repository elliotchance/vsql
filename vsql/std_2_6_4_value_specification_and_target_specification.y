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
  dynamic_parameter_specification {
    $$.v = $1.v as GeneralValueSpecification
  }
| CURRENT_CATALOG {
    flag(mut yylex, 'F762')
    $$.v = GeneralValueSpecification(CurrentCatalog{})
  }
| CURRENT_SCHEMA {
    flag(mut yylex, 'F763')
    $$.v = GeneralValueSpecification(CurrentSchema{})
  }

// A <simple value specification> can also be a <host parameter name>, <SQL
// parameter reference> or <embedded variable name>, which vsql doesn't support.
// It can't be a <dynamic parameter specification>.
simple_value_specification:
  literal { $$.v = ValueSpecification($1.v as Value) }

// A <dynamic parameter specification> is named by its position, such as "?1"
// for the first "?" (see tokenize).
dynamic_parameter_specification:
  question_mark {
    flag(mut yylex, 'B031')
    $$.v = GeneralValueSpecification(DynamicParameterSpecification{$1.v as string})
  }

%%
