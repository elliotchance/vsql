%%

// VACUUM isn't part of the standard (see vacuum.v).
vacuum_statement:
  VACUUM {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(VacuumStatement{}))
  }

%%
