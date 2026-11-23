%%

// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>
//
// Specify a datetime value.
//
// The <plus sign> and <minus sign> of datetime arithmetic are parsed as a
// numeric_value_expression (see compile_datetime_arithmetic).

datetime_value_expression:
  datetime_term { $$.v = $1.v }

datetime_term:
  datetime_factor { $$.v = $1.v }

// A value_expression_primary on its own is not a datetime_primary (see below),
// but it is when it's followed by a time_zone.
datetime_factor:
  datetime_primary { $$.v = $1.v }
| datetime_primary time_zone {
    $$.v = yy_box(DatetimePrimary(new_ref(TimeZoneExpression{$1.v as DatetimePrimary, $2.v as TimeZoneSpecifier})))
  }
| value_expression_primary time_zone {
    $$.v = yy_box(DatetimePrimary(new_ref(TimeZoneExpression{DatetimePrimary($1.v as ValueExpressionPrimary), $2.v as TimeZoneSpecifier})))
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
  AT time_zone_specifier {
    flag(mut yylex, 'F411')
    $$.v = $2.v
  }

// The interval_primary of TIME ZONE is a value_expression_primary, or an
// interval_qualified_primary (a dynamic parameter with an interval_qualifier).
time_zone_specifier:
  LOCAL { $$.v = yy_box(TimeZoneSpecifier{}) }
| TIME ZONE value_expression_primary {
    $$.v = yy_box(TimeZoneSpecifier{zone: new_ref(NumericPrimary($3.v as ValueExpressionPrimary))})
  }
| TIME ZONE interval_qualified_primary {
    $$.v = yy_box(TimeZoneSpecifier{zone: new_ref($3.v as NumericPrimary)})
  }

%%
