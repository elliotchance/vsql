%%

default_clause:
  DEFAULT default_option { $$.v = $2.v }

// USER, CURRENT_USER, CURRENT_ROLE, SESSION_USER, SYSTEM_USER and CURRENT_PATH
// aren't supported.
//
// ISO/IEC 9075-2:2023(E), 11.5, <default clause>, Conformance Rules, 4 and 5
default_option:
  literal { $$.v = yy_box(DefaultOption($1.v as Value)) }
| datetime_value_function {
    $$.v = yy_box(DefaultOption($1.v as DatetimeValueFunction))
  }
| CURRENT_CATALOG {
    flag(mut yylex, 'F762')
    $$.v = yy_box(DefaultOption(CurrentCatalog{}))
  }
| CURRENT_SCHEMA {
    flag(mut yylex, 'F763')
    $$.v = yy_box(DefaultOption(CurrentSchema{}))
  }
| implicitly_typed_value_specification {
    $$.v = yy_box(DefaultOption($1.v as NullSpecification))
  }

%%
