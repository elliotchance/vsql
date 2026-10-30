%%

default_clause:
  DEFAULT default_option { $$.v = $2.v as DefaultOption }

// USER, CURRENT_USER, CURRENT_ROLE, SESSION_USER, SYSTEM_USER and CURRENT_PATH
// aren't supported.
//
// ISO/IEC 9075-2:2016(E), 11.5, <default clause>, Conformance Rules, 4 and 5
default_option:
  literal { $$.v = DefaultOption($1.v as Value) }
| datetime_value_function {
    $$.v = DefaultOption($1.v as DatetimeValueFunction)
  }
| CURRENT_CATALOG {
    flag(mut yylex, 'F762')
    $$.v = DefaultOption(CurrentCatalog{})
  }
| CURRENT_SCHEMA {
    flag(mut yylex, 'F763')
    $$.v = DefaultOption(CurrentSchema{})
  }
| implicitly_typed_value_specification {
    $$.v = DefaultOption($1.v as NullSpecification)
  }

%%
