%%

literal:
  signed_numeric_literal { $$.v = $1.v }
| general_literal { $$.v = $1.v }

unsigned_literal:
  unsigned_numeric_literal { $$.v = $1.v }
| general_literal { $$.v = $1.v }

general_literal:
  character_string_literal { $$.v = $1.v }
| datetime_literal { $$.v = $1.v }
| boolean_literal { $$.v = $1.v }

character_string_literal:
  LITERAL_STRING { $$.v = $1.v }

signed_numeric_literal:
  unsigned_numeric_literal { $$.v = $1.v }
| sign unsigned_numeric_literal {
    $$.v = yy_box(signed_numeric_literal($1.v as string, $2.v as Value)!)
  }

unsigned_numeric_literal:
  exact_numeric_literal { $$.v = $1.v }
| approximate_numeric_literal { $$.v = $1.v }

exact_numeric_literal:
  unsigned_integer { $$.v = yy_box(numeric_literal($1.v as string)!) }
| unsigned_integer period { $$.v = yy_box(numeric_literal(($1.v as string) + '.')!) }
| unsigned_integer period unsigned_integer {
    $$.v = yy_box(numeric_literal(($1.v as string) + '.' + ($3.v as string))!)
  }
| period unsigned_integer { $$.v = yy_box(numeric_literal('0.' + ($2.v as string))!) }

sign:
  plus_sign { $$.v = $1.v as string }
| minus_sign { $$.v = $1.v as string }

approximate_numeric_literal:
  mantissa E exponent {
    $$.v = yy_box(approximate_numeric_literal_value(($1.v as Value).str() + 'e' +
      ($3.v as Value).str())!)
  }

mantissa:
  exact_numeric_literal { $$.v = $1.v }

exponent:
  signed_integer { $$.v = $1.v }

signed_integer:
  unsigned_integer { $$.v = yy_box(new_numeric_value($1.v as string)) }
| sign unsigned_integer {
    $$.v = yy_box(if $1.v as string == '-' {
      new_numeric_value('-' + ($2.v as string))
    } else {
      new_numeric_value($2.v as string)
    })
  }

unsigned_integer:
  LITERAL_NUMBER { $$.v = $1.v as string }

datetime_literal:
  date_literal { $$.v = $1.v }
| time_literal { $$.v = $1.v }
| timestamp_literal { $$.v = $1.v }

date_literal:
  DATE date_string { $$.v = yy_box(new_date_value(($2.v as Value).string_value())!) }

time_literal:
  TIME time_string {
    flag_datetime_literal(mut yylex, ($2.v as Value).string_value(), false)
    $$.v = yy_box(new_time_value(($2.v as Value).string_value())!)
  }

timestamp_literal:
  TIMESTAMP timestamp_string {
    flag_datetime_literal(mut yylex, ($2.v as Value).string_value(), true)
    $$.v = yy_box(new_timestamp_value(($2.v as Value).string_value())!)
  }

date_string:
  LITERAL_STRING { $$.v = $1.v }

time_string:
  LITERAL_STRING { $$.v = $1.v }

timestamp_string:
  LITERAL_STRING { $$.v = $1.v }

boolean_literal:
  TRUE {
    flag(mut yylex, 'T031')
    $$.v = yy_box(new_boolean_value(true))
  }
| FALSE {
    flag(mut yylex, 'T031')
    $$.v = yy_box(new_boolean_value(false))
  }
| UNKNOWN {
    flag(mut yylex, 'T031')
    $$.v = yy_box(new_unknown_value())
  }

%%
