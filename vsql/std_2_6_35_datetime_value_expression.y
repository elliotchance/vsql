%%

// ISO/IEC 9075-2:2016(E), 6.35, <datetime value expression>
//
// Specify a datetime value.
//
// There's no datetime arithmetic (F052) or AT LOCAL and AT TIME ZONE (F411).

datetime_value_expression:
  datetime_term { $$.v = $1.v as DatetimePrimary }

datetime_term:
  datetime_factor { $$.v = $1.v as DatetimePrimary }

datetime_factor:
  datetime_primary { $$.v = $1.v as DatetimePrimary }

// A value_expression_primary is not a datetime_primary here because there are
// no datetime operators, so it would be the same as a numeric_primary or a
// character_primary (and the parser can't tell which one it is).
datetime_primary:
  datetime_value_function {
    $$.v = DatetimePrimary($1.v as DatetimeValueFunction)
  }

%%
