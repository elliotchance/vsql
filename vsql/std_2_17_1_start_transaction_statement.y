%%

start_transaction_statement:
  START TRANSACTION {
    flag(mut yylex, 'T241')
    $$.v = Stmt(StartTransactionStatement{})
  }
| START TRANSACTION transaction_characteristics {
    flag(mut yylex, 'T241')
    $$.v = Stmt(StartTransactionStatement{$3.v as []TransactionMode})
  }

%%
