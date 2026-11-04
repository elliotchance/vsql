%%

rollback_statement:
  ROLLBACK { $$.v = yy_box(Stmt(RollbackStatement{})) }
| ROLLBACK WORK { $$.v = yy_box(Stmt(RollbackStatement{})) }
| ROLLBACK and_chain { $$.v = yy_box(Stmt(RollbackStatement{chain: $2.v as bool})) }
| ROLLBACK WORK and_chain { $$.v = yy_box(Stmt(RollbackStatement{chain: $3.v as bool})) }
| ROLLBACK savepoint_clause {
    $$.v = yy_box(Stmt(RollbackStatement{savepoint: $2.v as string}))
  }
| ROLLBACK WORK savepoint_clause {
    $$.v = yy_box(Stmt(RollbackStatement{savepoint: $3.v as string}))
  }
| ROLLBACK and_chain savepoint_clause {
    $$.v = yy_box(Stmt(RollbackStatement{chain: $2.v as bool, savepoint: $3.v as string}))
  }
| ROLLBACK WORK and_chain savepoint_clause {
    $$.v = yy_box(Stmt(RollbackStatement{chain: $3.v as bool, savepoint: $4.v as string}))
  }
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

// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, Conformance Rules, 1

savepoint_clause:
  TO SAVEPOINT savepoint_name {
    flag(mut yylex, 'T271')
    $$.v = $3.v as string
  }

%%
