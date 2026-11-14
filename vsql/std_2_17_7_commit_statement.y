%%

commit_statement:
  COMMIT { $$.v = yy_box(Stmt(CommitStatement{})) }
| COMMIT WORK { $$.v = yy_box(Stmt(CommitStatement{})) }
| COMMIT and_chain { $$.v = yy_box(Stmt(CommitStatement{chain: $2.v as bool})) }
| COMMIT WORK and_chain { $$.v = yy_box(Stmt(CommitStatement{chain: $3.v as bool})) }
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

// ISO/IEC 9075-2:2023(E), 17.7, <commit statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2023(E), 17.8, <rollback statement>, Conformance Rules, 2

and_chain:
  AND CHAIN {
    flag(mut yylex, 'T261')
    $$.v = true
  }
| AND NO CHAIN {
    flag(mut yylex, 'T261')
    $$.v = false
  }

%%
