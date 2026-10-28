%%

start_transaction_statement:
  START TRANSACTION { $$.v = Stmt(StartTransactionStatement{}) }
| START TRANSACTION transaction_characteristics {
    $$.v = Stmt(StartTransactionStatement{$3.v as []IsolationLevel})
  }

%%
