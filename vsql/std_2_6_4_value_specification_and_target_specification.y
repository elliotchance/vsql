%%

value_specification:
  literal { $$.v = yy_box(ValueSpecification($1.v as Value)) }
| general_value_specification {
    $$.v = yy_box(ValueSpecification($1.v as GeneralValueSpecification))
  }

unsigned_value_specification:
  unsigned_literal { $$.v = yy_box(ValueSpecification($1.v as Value)) }
| general_value_specification {
    $$.v = yy_box(ValueSpecification($1.v as GeneralValueSpecification))
  }

general_value_specification:
  dynamic_parameter_specification {
    $$.v = $1.v
  }
| CURRENT_CATALOG {
    flag(mut yylex, 'F762')
    $$.v = yy_box(GeneralValueSpecification(CurrentCatalog{}))
  }
| CURRENT_SCHEMA {
    flag(mut yylex, 'F763')
    $$.v = yy_box(GeneralValueSpecification(CurrentSchema{}))
  }

// A <simple value specification> can also be a <host parameter name>, <SQL
// parameter reference> or <embedded variable name>, which vsql doesn't support.
// It can't be a <dynamic parameter specification>.
simple_value_specification:
  literal { $$.v = yy_box(ValueSpecification($1.v as Value)) }

// A <dynamic parameter specification> is named by its position, such as "?1"
// for the first "?" (see tokenize).
dynamic_parameter_specification:
  question_mark {
    flag(mut yylex, 'B031')
    $$.v = yy_box(GeneralValueSpecification(DynamicParameterSpecification{$1.v as string}))
  }

%%
