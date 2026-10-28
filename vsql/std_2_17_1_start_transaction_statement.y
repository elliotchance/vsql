%%

start_transaction_statement:
  START TRANSACTION {
    flag(mut yylex, 'T241')
    $$.v = Stmt(StartTransactionStatement{})
  }

%%
