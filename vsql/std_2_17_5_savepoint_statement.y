%%

// ISO/IEC 9075-2:2016(E), 17.5, <savepoint statement>, Conformance Rules, 1

savepoint_statement:
  SAVEPOINT savepoint_name {
    flag(mut yylex, 'T271')
    $$.v = yy_box(Stmt(SavepointStatement{$2.v as string}))
  }

// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Conformance Rules, 2

savepoint_name:
  identifier {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!.sub_entity_name
  }

%%
