%%

commit_statement:
  COMMIT { $$.v = Stmt(CommitStatement{}) }
| COMMIT WORK { $$.v = Stmt(CommitStatement{}) }

%%
