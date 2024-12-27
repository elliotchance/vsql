%%

datetime_value_expression:
  datetime_term { $$.v = $1.v as DatetimePrimary }

datetime_term:
  datetime_factor { $$.v = $1.v as DatetimePrimary }

datetime_factor:
  datetime_primary { $$.v = $1.v as DatetimePrimary }

// Note: datetime_primary is defined in grammar.y. See there for details.

%%
