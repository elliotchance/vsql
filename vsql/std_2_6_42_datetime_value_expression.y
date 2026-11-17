%%

// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>
//
// Specify a datetime value.
//
// There's no datetime arithmetic (F052), and AT TIME ZONE needs an interval
// (F052) too, so only AT LOCAL is a <time zone>.

datetime_value_expression:
  datetime_term { $$.v = $1.v }

datetime_term:
  datetime_factor { $$.v = $1.v }

// A value_expression_primary on its own is not a datetime_primary (see below),
// but it is when it's followed by a time_zone.
datetime_factor:
  datetime_primary { $$.v = $1.v }
| datetime_primary time_zone {
    $$.v = yy_box(DatetimePrimary(new_ref(TimeZoneExpression{$1.v as DatetimePrimary})))
  }
| value_expression_primary time_zone {
    $$.v = yy_box(DatetimePrimary(new_ref(TimeZoneExpression{DatetimePrimary($1.v as ValueExpressionPrimary)})))
  }

// A value_expression_primary is not a datetime_primary here because there are
// no datetime operators, so it would be the same as a numeric_primary or a
// character_primary (and the parser can't tell which one it is).
datetime_primary:
  datetime_value_function {
    $$.v = yy_box(DatetimePrimary($1.v as DatetimeValueFunction))
  }

// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, Conformance Rules, 2
time_zone:
  AT time_zone_specifier { flag(mut yylex, 'F411') }

time_zone_specifier:
  LOCAL

%%
