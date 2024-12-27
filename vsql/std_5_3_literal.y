%%

literal:
  signed_numeric_literal { $$.v = $1.v as Value }
| general_literal { $$.v = $1.v as Value }

unsigned_literal:
  unsigned_numeric_literal { $$.v = $1.v as Value }
| general_literal { $$.v = $1.v as Value }

general_literal:
  character_string_literal { $$.v = $1.v as Value }
| datetime_literal { $$.v = $1.v as Value }
| boolean_literal { $$.v = $1.v as Value }

character_string_literal:
  LITERAL_STRING { $$.v = $1.v as Value }

signed_numeric_literal:
  unsigned_numeric_literal { $$.v = $1.v as Value }
| sign unsigned_numeric_literal {
    $$.v = numeric_literal($1.v as string + ($2.v as Value).str())!
  }

unsigned_numeric_literal:
  exact_numeric_literal { $$.v = $1.v as Value }
| approximate_numeric_literal { $$.v = $1.v as Value }

exact_numeric_literal:
  unsigned_integer { $$.v = numeric_literal($1.v as string)! }
| unsigned_integer period { $$.v = numeric_literal(($1.v as string) + '.')! }
| unsigned_integer period unsigned_integer {
    $$.v = numeric_literal(($1.v as string) + '.' + ($3.v as string))!
  }
| period unsigned_integer { $$.v = numeric_literal('0.' + ($2.v as string))! }

sign:
  plus_sign { $$.v = $1.v as string }
| minus_sign { $$.v = $1.v as string }

approximate_numeric_literal:
  mantissa E exponent {
    $$.v = new_double_precision_value(
      ($1.v as Value).as_f64()! * math.pow(10, ($3.v as Value).as_f64()!))
  }

mantissa:
  exact_numeric_literal { $$.v = $1.v as Value }

exponent:
  signed_integer { $$.v = $1.v as Value }

signed_integer:
  unsigned_integer { $$.v = new_numeric_value($1.v as string) }
| sign unsigned_integer {
    $$.v = if $1.v as string == '-' {
      new_numeric_value('-' + ($2.v as string))
    } else {
      new_numeric_value($2.v as string)
    }
  }

unsigned_integer:
  LITERAL_NUMBER { $$.v = $1.v as string }

datetime_literal:
  date_literal { $$.v = $1.v as Value }
| time_literal { $$.v = $1.v as Value }
| timestamp_literal { $$.v = $1.v as Value }

date_literal:
  DATE date_string { $$.v = new_date_value(($2.v as Value).string_value())! }

time_literal:
  TIME time_string { $$.v = new_time_value(($2.v as Value).string_value())! }

timestamp_literal:
  TIMESTAMP timestamp_string {
    $$.v = new_timestamp_value(($2.v as Value).string_value())!
  }

date_string:
  LITERAL_STRING { $$.v = $1.v as Value }

time_string:
  LITERAL_STRING { $$.v = $1.v as Value }

timestamp_string:
  LITERAL_STRING { $$.v = $1.v as Value }

boolean_literal:
  TRUE { $$.v = new_boolean_value(true) }
| FALSE { $$.v = new_boolean_value(false) }
| UNKNOWN { $$.v = new_unknown_value() }

%%
