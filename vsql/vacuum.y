%%

// VACUUM isn't part of the standard (see vacuum.v).
vacuum_statement:
  VACUUM {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(VacuumStatement{}))
  }
| VACUUM ON vacuum_objects {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_statement($3.v as []VacuumObject, [])!))
  }
| VACUUM vacuum_options {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_statement([], $2.v as []VacuumOption)!))
  }
| VACUUM ON vacuum_objects vacuum_options {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_statement($3.v as []VacuumObject,
      $4.v as []VacuumOption)!))
  }
| VACUUM ANALYZE {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_analyze_statement([], [])!))
  }
| VACUUM ANALYZE ON vacuum_objects {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_analyze_statement($4.v as []VacuumObject, [])!))
  }
| VACUUM ANALYZE vacuum_options {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_analyze_statement([], $3.v as []VacuumOption)!))
  }
| VACUUM ANALYZE ON vacuum_objects vacuum_options {
    flag(mut yylex, vsql_vacuum)
    $$.v = yy_box(Stmt(new_vacuum_analyze_statement($4.v as []VacuumObject,
      $5.v as []VacuumOption)!))
  }

vacuum_objects:
  vacuum_object { $$.v = yy_box([$1.v as VacuumObject]) }
| vacuum_objects vacuum_object {
    $$.v = yy_box(append_list($1.v as []VacuumObject, $2.v as VacuumObject))
  }

vacuum_object:
  ALL { $$.v = yy_box(VacuumObject{ kind: .all }) }
| CATALOG identifier {
    $$.v = yy_box(new_vacuum_catalog(($2.v as IdentifierChain).identifier)!)
  }
| SCHEMA schema_name {
    $$.v = yy_box(VacuumObject{ kind: .schema, name: $2.v as Identifier })
  }
| TABLE table_name { $$.v = yy_box(new_vacuum_table($2.v as Identifier, [])!) }
| TABLE table_name vacuum_table_clauses {
    $$.v = yy_box(new_vacuum_table($2.v as Identifier, $3.v as []VacuumTableClause)!)
  }
| INDEX schema_qualified_name {
    $$.v = yy_box(VacuumObject{
      kind: .index
      name: new_table_identifier(($2.v as IdentifierChain).identifier)!
    })
  }

vacuum_table_clauses:
  vacuum_table_clause { $$.v = yy_box([$1.v as VacuumTableClause]) }
| vacuum_table_clauses vacuum_table_clause {
    $$.v = yy_box(append_list($1.v as []VacuumTableClause, $2.v as VacuumTableClause))
  }

vacuum_table_clause:
  WITH INDEXES { $$.v = yy_box(VacuumTableClause{ with: true }) }
| WITHOUT INDEXES { $$.v = yy_box(VacuumTableClause{}) }
| WITH LARGE OBJECTS {
    $$.v = yy_box(VacuumTableClause{ large_objects: true, with: true })
  }
| WITHOUT LARGE OBJECTS { $$.v = yy_box(VacuumTableClause{ large_objects: true }) }

vacuum_options:
  vacuum_option { $$.v = yy_box([$1.v as VacuumOption]) }
| vacuum_options vacuum_option {
    $$.v = yy_box(append_list($1.v as []VacuumOption, $2.v as VacuumOption))
  }

vacuum_option:
  COMPACT { $$.v = yy_box(VacuumOption{ kind: .compact }) }
| FULL { $$.v = yy_box(VacuumOption{ kind: .full }) }
| FREE PAGES { $$.v = yy_box(VacuumOption{ kind: .free_pages }) }
| TIMEOUT unsigned_numeric_literal {
    $$.v = yy_box(VacuumOption{ kind: .timeout, timeout: $2.v as Value })
  }

%%
