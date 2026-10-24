%%

datetime_value_function:
  current_date_value_function {
    $$.v = DatetimeValueFunction($1.v as CurrentDate)
  }
| current_time_value_function {
    $$.v = DatetimeValueFunction($1.v as CurrentTime)
  }
| current_timestamp_value_function {
    $$.v = DatetimeValueFunction($1.v as CurrentTimestamp)
  }
| current_local_time_value_function {
    $$.v = DatetimeValueFunction($1.v as LocalTime)
  }
| current_local_timestamp_value_function {
    $$.v = DatetimeValueFunction($1.v as LocalTimestamp)
  }

current_date_value_function:
  CURRENT_DATE { $$.v = CurrentDate{} }

current_time_value_function:
  CURRENT_TIME { $$.v = CurrentTime{default_time_precision} }
| CURRENT_TIME left_paren time_precision right_paren {
    $$.v = CurrentTime{($3.v as string).int()}
  }

current_local_time_value_function:
  LOCALTIME { $$.v = LocalTime{0} }
| LOCALTIME left_paren time_precision right_paren {
    $$.v = LocalTime{($3.v as string).int()}
  }

current_timestamp_value_function:
  CURRENT_TIMESTAMP { $$.v = CurrentTimestamp{default_timestamp_precision} }
| CURRENT_TIMESTAMP left_paren timestamp_precision right_paren {
    $$.v = CurrentTimestamp{($3.v as string).int()}
  }

current_local_timestamp_value_function:
  LOCALTIMESTAMP { $$.v = LocalTimestamp{6} }
| LOCALTIMESTAMP left_paren timestamp_precision right_paren {
    $$.v = LocalTimestamp{($3.v as string).int()}
  }

%%
