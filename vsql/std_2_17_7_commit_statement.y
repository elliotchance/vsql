%%

commit_statement:
  COMMIT { $$.v = Stmt(CommitStatement{}) }
| COMMIT WORK { $$.v = Stmt(CommitStatement{}) }
// These aren't part of the standard (see the V013 feature in the SQL Flagger).
| COMMIT TRANSACTION {
    flag(mut yylex, vsql_commit_transaction)
    $$.v = Stmt(CommitStatement{})
  }
| END {
    flag(mut yylex, vsql_end)
    $$.v = Stmt(CommitStatement{})
  }
| END TRANSACTION {
    flag(mut yylex, vsql_end)
    $$.v = Stmt(CommitStatement{})
  }
| END WORK {
    flag(mut yylex, vsql_end)
    $$.v = Stmt(CommitStatement{})
  }

%%
