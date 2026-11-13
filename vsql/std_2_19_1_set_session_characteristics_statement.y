%%

// ISO/IEC 9075-2:2016(E), 19.1, <set session characteristics statement>, Conformance Rules, 1

set_session_characteristics_statement:
  SET SESSION CHARACTERISTICS AS session_characteristic_list {
    flag(mut yylex, 'F761')
    $$.v = yy_box(Stmt(SetSessionCharacteristicsStatement{$5.v as []TransactionMode}))
  }

// Each <session characteristic> is TRANSACTION followed by a list of modes, which
// are all commas, so one token isn't enough to tell where each one ends. They are
// all treated as one list.

session_characteristic_list:
  TRANSACTION transaction_mode { $$.v = yy_box([$2.v as TransactionMode]) }
| session_characteristic_list comma transaction_mode {
    $$.v = yy_box(append_list($1.v as []TransactionMode, $3.v as TransactionMode))
  }
| session_characteristic_list comma TRANSACTION transaction_mode {
    $$.v = yy_box(append_list($1.v as []TransactionMode, $4.v as TransactionMode))
  }

%%
