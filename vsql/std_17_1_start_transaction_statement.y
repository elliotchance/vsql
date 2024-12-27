%%

start_transaction_statement:
  START TRANSACTION { $$.v = Stmt(StartTransactionStatement{}) }

%%
