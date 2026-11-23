%%

// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>
//
// The <interval value expression> of a <set time zone value> can be any
// value_expression, whose type is checked when it's executed.
//
// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>, Conformance Rules, 1

set_local_time_zone_statement:
  SET TIME ZONE LOCAL {
    flag(mut yylex, 'F411')
    $$.v = yy_box(Stmt(SetLocalTimeZoneStatement{}))
  }
| SET TIME ZONE value_expression {
    flag(mut yylex, 'F411')
    $$.v = yy_box(Stmt(SetLocalTimeZoneStatement{value: $4.v as ValueExpression}))
  }

%%
