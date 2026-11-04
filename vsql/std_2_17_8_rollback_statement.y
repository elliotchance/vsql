%%

rollback_statement:
  ROLLBACK { $$.v = Stmt(RollbackStatement{}) }
| ROLLBACK WORK { $$.v = Stmt(RollbackStatement{}) }
// These aren't part of the standard (see the V013 feature in the SQL Flagger).
| ROLLBACK TRANSACTION {
    flag(mut yylex, vsql_rollback_transaction)
    $$.v = Stmt(RollbackStatement{})
  }
| ABORT {
    flag(mut yylex, vsql_abort)
    $$.v = Stmt(RollbackStatement{})
  }
| ABORT TRANSACTION {
    flag(mut yylex, vsql_abort)
    $$.v = Stmt(RollbackStatement{})
  }
| ABORT WORK {
    flag(mut yylex, vsql_abort)
    $$.v = Stmt(RollbackStatement{})
  }

%%
