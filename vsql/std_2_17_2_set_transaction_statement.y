%%

set_transaction_statement:
  SET TRANSACTION { $$.v = Stmt(SetTransactionStatement{}) }
| SET TRANSACTION transaction_characteristics {
    $$.v = Stmt(SetTransactionStatement{$3.v as []TransactionMode})
  }

%%
