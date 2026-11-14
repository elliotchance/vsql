%%

// ISO/IEC 9075-2:2023(E), 17.6, <release savepoint statement>, Conformance Rules, 1

release_savepoint_statement:
  RELEASE SAVEPOINT savepoint_name {
    flag(mut yylex, 'T271')
    $$.v = yy_box(Stmt(ReleaseSavepointStatement{$3.v as string}))
  }

%%
