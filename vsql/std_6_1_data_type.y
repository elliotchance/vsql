%%

data_type:
  predefined_type { $$.v = $1.v as Type }

predefined_type:
  character_string_type { $$.v = $1.v as Type }
| numeric_type { $$.v = $1.v as Type }
| boolean_type { $$.v = $1.v as Type }
| datetime_type { $$.v = $1.v as Type }

character_string_type:
  CHARACTER { $$.v = new_type('CHARACTER', 1, 0) }
| CHARACTER left_paren character_length right_paren {
    $$.v = new_type('CHARACTER', ($3.v as string).int(), 0)
  }
| CHAR { $$.v = new_type('CHARACTER', 1, 0) }
| CHAR left_paren character_length right_paren {
    $$.v = new_type('CHARACTER', ($3.v as string).int(), 0)
  }
| CHARACTER VARYING left_paren character_length right_paren {
    $$.v = new_type('CHARACTER VARYING', ($4.v as string).int(), 0)
  }
| CHAR VARYING left_paren character_length right_paren {
    $$.v = new_type('CHARACTER VARYING', ($4.v as string).int(), 0)
  }
| VARCHAR left_paren character_length right_paren {
    $$.v = new_type('CHARACTER VARYING', ($3.v as string).int(), 0)
  }

numeric_type:
  exact_numeric_type { $$.v = $1.v as Type }
| approximate_numeric_type { $$.v = $1.v as Type }

exact_numeric_type:
  NUMERIC { $$.v = new_type('NUMERIC', 0, 0) }
| NUMERIC left_paren precision right_paren {
    $$.v = new_type('NUMERIC', ($3.v as string).int(), 0)
  }
| NUMERIC left_paren precision comma scale right_paren {
    $$.v = new_type('NUMERIC', ($3.v as string).int(), ($5.v as string).i16())
  }
| DECIMAL { $$.v = new_type('DECIMAL', 0, 0) }
| DECIMAL left_paren precision right_paren {
    $$.v = new_type('DECIMAL', ($3.v as string).int(), 0)
  }
| DECIMAL left_paren precision comma scale right_paren {
    $$.v = new_type('DECIMAL', ($3.v as string).int(), ($5.v as string).i16())
  }
| SMALLINT { $$.v = new_type('SMALLINT', 0, 0) }
| INTEGER { $$.v = new_type('INTEGER', 0, 0) }
| INT { $$.v = new_type('INTEGER', 0, 0) }
| BIGINT { $$.v = new_type('BIGINT', 0, 0) }

approximate_numeric_type:
  FLOAT { $$.v = new_type('FLOAT', 0, 0) }
| FLOAT left_paren precision right_paren {
    $$.v = new_type('FLOAT', ($3.v as string).int(), 0)
  }
| REAL { $$.v = new_type('REAL', 0, 0) }
| DOUBLE PRECISION { $$.v = new_type('DOUBLE PRECISION', 0, 0) }

length:
  unsigned_integer { $$.v = $1.v as string }

character_length:
  length { $$.v = $1.v as string }

char_length_units:
  CHARACTERS { $$.v = $1.v as string }
| OCTETS { $$.v = $1.v as string }

precision:
  unsigned_integer { $$.v = $1.v as string }

scale:
  unsigned_integer { $$.v = $1.v as string }

boolean_type:
  BOOLEAN { $$.v = new_type('BOOLEAN', 0, 0) }

datetime_type:
  DATE { $$.v = new_type('DATE', 0, 0) }
| TIME { $$.v = parse_time_prec_tz_type('0', false)! }
| TIME left_paren time_precision right_paren {
    $$.v = parse_time_prec_tz_type($3.v as string, false)!
  }
| TIME with_or_without_time_zone {
    $$.v = parse_time_prec_tz_type('0', $2.v as bool)!
  }
| TIME left_paren time_precision right_paren with_or_without_time_zone {
    $$.v = parse_time_prec_tz_type($3.v as string, $5.v as bool)!
  }
| TIMESTAMP { $$.v = parse_timestamp_prec_tz_type('0', false)! }
| TIMESTAMP left_paren timestamp_precision right_paren {
    $$.v = parse_timestamp_prec_tz_type($3.v as string, false)!
  }
| TIMESTAMP with_or_without_time_zone {
  // ISO/IEC 9075-2:2016(E), 6.1, 36) If <timestamp precision> is not
  // specified, then 6 is implicit.
  $$.v = parse_timestamp_prec_tz_type('6', $2.v as bool)!
}
| TIMESTAMP left_paren timestamp_precision right_paren
  with_or_without_time_zone {
    $$.v = parse_timestamp_prec_tz_type($3.v as string, $5.v as bool)!
  }

with_or_without_time_zone:
  WITH TIME ZONE { $$.v = true }
| WITHOUT TIME ZONE { $$.v = false }

time_precision:
  time_fractional_seconds_precision { $$.v = $1.v as string }

timestamp_precision:
  time_fractional_seconds_precision { $$.v = $1.v as string }

time_fractional_seconds_precision:
  unsigned_integer { $$.v = $1.v as string }

%%
