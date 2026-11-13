%%

rollback_statement:
  ROLLBACK { $$.v = yy_box(Stmt(RollbackStatement{})) }
| ROLLBACK WORK { $$.v = yy_box(Stmt(RollbackStatement{})) }
| ROLLBACK and_chain { $$.v = yy_box(Stmt(RollbackStatement{chain: $2.v as bool})) }
| ROLLBACK WORK and_chain { $$.v = yy_box(Stmt(RollbackStatement{chain: $3.v as bool})) }
// These aren't part of the standard (see the V114 feature in the SQL Flagger).
| ROLLBACK TRANSACTION {
    flag(mut yylex, vsql_rollback_transaction)
    $$.v = yy_box(Stmt(RollbackStatement{}))
  }
| ABORT {
    flag(mut yylex, vsql_abort)
    $$.v = yy_box(Stmt(RollbackStatement{}))
  }
| ABORT TRANSACTION {
    flag(mut yylex, vsql_abort)
    $$.v = yy_box(Stmt(RollbackStatement{}))
  }
| ABORT WORK {
    flag(mut yylex, vsql_abort)
    $$.v = yy_box(Stmt(RollbackStatement{}))
  }

%%
