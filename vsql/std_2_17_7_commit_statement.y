%%

commit_statement:
  COMMIT { $$.v = yy_box(Stmt(CommitStatement{})) }
| COMMIT WORK { $$.v = yy_box(Stmt(CommitStatement{})) }
// These aren't part of the standard (see the V114 feature in the SQL Flagger).
| COMMIT TRANSACTION {
    flag(mut yylex, vsql_commit_transaction)
    $$.v = yy_box(Stmt(CommitStatement{}))
  }
| END {
    flag(mut yylex, vsql_end)
    $$.v = yy_box(Stmt(CommitStatement{}))
  }
| END TRANSACTION {
    flag(mut yylex, vsql_end)
    $$.v = yy_box(Stmt(CommitStatement{}))
  }
| END WORK {
    flag(mut yylex, vsql_end)
    $$.v = yy_box(Stmt(CommitStatement{}))
  }

%%
