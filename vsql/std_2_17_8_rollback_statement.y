%%

rollback_statement:
  ROLLBACK { $$.v = Stmt(RollbackStatement{}) }
| ROLLBACK WORK { $$.v = Stmt(RollbackStatement{}) }
| ROLLBACK and_chain { $$.v = Stmt(RollbackStatement{chain: $2.v as bool}) }
| ROLLBACK WORK and_chain { $$.v = Stmt(RollbackStatement{chain: $3.v as bool}) }

%%
