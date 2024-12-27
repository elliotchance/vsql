%%

rollback_statement:
  ROLLBACK { $$.v = Stmt(RollbackStatement{}) }
| ROLLBACK WORK { $$.v = Stmt(RollbackStatement{}) }

%%
