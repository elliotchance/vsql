%%

commit_statement:
  COMMIT { $$.v = Stmt(CommitStatement{}) }
| COMMIT WORK { $$.v = Stmt(CommitStatement{}) }
| COMMIT and_chain { $$.v = Stmt(CommitStatement{chain: $2.v as bool}) }
| COMMIT WORK and_chain { $$.v = Stmt(CommitStatement{chain: $3.v as bool}) }

// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, Conformance Rules, 2

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
