%%

// VACUUM isn't part of the standard (see vacuum.v).
vacuum_statement:
  VACUUM {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(VacuumStatement{}))
  }
| VACUUM vacuum_options {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_statement($2.v as []VacuumOption)!))
  }

vacuum_options:
  vacuum_option { $$.v = yy_box([$1.v as VacuumOption]) }
| vacuum_options vacuum_option {
    $$.v = yy_box(append_list($1.v as []VacuumOption, $2.v as VacuumOption))
  }

vacuum_option:
  COMPACT { $$.v = yy_box(VacuumOption{ kind: .compact }) }
| FULL { $$.v = yy_box(VacuumOption{ kind: .full }) }
| FREE PAGES { $$.v = yy_box(VacuumOption{ kind: .free_pages }) }
| VERBOSE { $$.v = yy_box(VacuumOption{ kind: .verbose }) }
| TIMEOUT unsigned_numeric_literal {
    $$.v = yy_box(VacuumOption{ kind: .timeout, timeout: $2.v as Value })
  }

%%
