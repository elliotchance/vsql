%%

set_transaction_statement:
  SET TRANSACTION { $$.v = yy_box(Stmt(SetTransactionStatement{})) }
| SET TRANSACTION transaction_characteristics {
    $$.v = yy_box(Stmt(SetTransactionStatement{$3.v as []TransactionMode}))
  }

%%
