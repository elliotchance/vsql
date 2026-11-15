%%

interval_qualifier:
  start_field TO end_field {
    start := $1.v as IntervalFieldPrecision
    end := $3.v as IntervalFieldPrecision
    $$.v = yy_box(parse_interval_range(start, end)!)
  }
| single_datetime_field { $$.v = $1.v }

start_field:
  non_second_primary_datetime_field {
    $$.v = yy_box(IntervalFieldPrecision{interval_field_from_string($1.v as string), -1})
  }
| non_second_primary_datetime_field left_paren interval_leading_field_precision
  right_paren {
    $$.v = yy_box(IntervalFieldPrecision{interval_field_from_string($1.v as string), ($3.v as string).int()})
  }

end_field:
  non_second_primary_datetime_field {
    $$.v = yy_box(IntervalFieldPrecision{interval_field_from_string($1.v as string), -1})
  }
| SECOND { $$.v = yy_box(IntervalFieldPrecision{.second, -1}) }
| SECOND left_paren interval_fractional_seconds_precision right_paren {
    $$.v = yy_box(IntervalFieldPrecision{.second, ($3.v as string).int()})
  }

single_datetime_field:
  non_second_primary_datetime_field {
    field := interval_field_from_string($1.v as string)
    $$.v = yy_box(parse_interval_qualifier(field, field, -1, -1)!)
  }
| non_second_primary_datetime_field left_paren interval_leading_field_precision
  right_paren {
    field := interval_field_from_string($1.v as string)
    $$.v = yy_box(parse_interval_qualifier(field, field, ($3.v as string).int(), -1)!)
  }
| SECOND { $$.v = yy_box(parse_interval_qualifier(.second, .second, -1, -1)!) }
| SECOND left_paren interval_leading_field_precision right_paren {
    $$.v = yy_box(parse_interval_qualifier(.second, .second, ($3.v as string).int(), -1)!)
  }
| SECOND left_paren interval_leading_field_precision comma
  interval_fractional_seconds_precision right_paren {
    $$.v = yy_box(parse_interval_qualifier(.second, .second, ($3.v as string).int(),
      ($5.v as string).int())!)
  }

primary_datetime_field:
  non_second_primary_datetime_field { $$.v = $1.v }
| SECOND { $$.v = 'SECOND' }

non_second_primary_datetime_field:
  YEAR { $$.v = $1.v as string }
| MONTH { $$.v = $1.v as string }
| DAY { $$.v = $1.v as string }
| HOUR { $$.v = $1.v as string }
| MINUTE { $$.v = $1.v as string }

interval_fractional_seconds_precision:
  unsigned_integer { $$.v = $1.v as string }

interval_leading_field_precision:
  unsigned_integer { $$.v = $1.v as string }

%%
