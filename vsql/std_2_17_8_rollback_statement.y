%%

rollback_statement:
  ROLLBACK { $$.v = Stmt(RollbackStatement{}) }
| ROLLBACK WORK { $$.v = Stmt(RollbackStatement{}) }
| ROLLBACK and_chain { $$.v = Stmt(RollbackStatement{chain: $2.v as bool}) }
| ROLLBACK WORK and_chain { $$.v = Stmt(RollbackStatement{chain: $3.v as bool}) }
| ROLLBACK savepoint_clause {
    $$.v = Stmt(RollbackStatement{savepoint: $2.v as string})
  }
| ROLLBACK WORK savepoint_clause {
    $$.v = Stmt(RollbackStatement{savepoint: $3.v as string})
  }
| ROLLBACK and_chain savepoint_clause {
    $$.v = Stmt(RollbackStatement{chain: $2.v as bool, savepoint: $3.v as string})
  }
| ROLLBACK WORK and_chain savepoint_clause {
    $$.v = Stmt(RollbackStatement{chain: $3.v as bool, savepoint: $4.v as string})
  }

// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, Conformance Rules, 1

savepoint_clause:
  TO SAVEPOINT savepoint_name {
    flag(mut yylex, 'T271')
    $$.v = $3.v as string
  }

%%
