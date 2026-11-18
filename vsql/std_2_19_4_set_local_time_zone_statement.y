%%

// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>
//
// Only LOCAL is a <set time zone value> for now, since there are no intervals
// (F052) for the other one.
//
// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>, Conformance Rules, 1

set_local_time_zone_statement:
  SET TIME ZONE LOCAL {
    flag(mut yylex, 'F411')
    $$.v = yy_box(Stmt(SetLocalTimeZoneStatement{}))
  }

%%
