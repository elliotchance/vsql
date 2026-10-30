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

// Note: datetime_primary is defined in grammar.y. See there for details.

%%
