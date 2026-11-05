%%

// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>
//
// Define all of the SQL-statements that are <SQL procedure statement>s.

// Only the <SQL data statement>s that aren't also a <preparable statement> are
// here. They use a standing cursor, which can only be declared outside of an
// SQL-client module as a vsql extension (see declare_cursor).
sql_data_statement:
  open_statement { $$.v = $1.v as Stmt }
| fetch_statement { $$.v = $1.v as Stmt }
| close_statement { $$.v = $1.v as Stmt }
| delete_statement_positioned { $$.v = $1.v as Stmt }
| update_statement_positioned { $$.v = $1.v as Stmt }

sql_schema_statement:
  sql_schema_definition_statement { $$.v = $1.v as Stmt }
| sql_schema_manipulation_statement { $$.v = $1.v as Stmt }

sql_schema_definition_statement:
  schema_definition { $$.v = $1.v as Stmt }
| table_definition { $$.v = Stmt($1.v as TableDefinition) }
| sequence_generator_definition { $$.v = Stmt($1.v as SequenceGeneratorDefinition) }
| create_index_statement { $$.v = $1.v as Stmt }

sql_schema_manipulation_statement:
  drop_schema_statement { $$.v = $1.v as Stmt }
| alter_table_statement { $$.v = $1.v as Stmt }
| drop_table_statement { $$.v = $1.v as Stmt }
| alter_sequence_generator_statement { $$.v = Stmt($1.v as AlterSequenceGeneratorStatement) }
| drop_sequence_generator_statement { $$.v = $1.v as Stmt }
| drop_index_statement { $$.v = $1.v as Stmt }

sql_transaction_statement:
  start_transaction_statement { $$.v = $1.v as Stmt }
| commit_statement { $$.v = $1.v as Stmt }
| rollback_statement { $$.v = $1.v as Stmt }
| set_transaction_statement { $$.v = $1.v as Stmt }
| set_constraints_mode_statement { $$.v = $1.v as Stmt }

// A <connection name> is only in a connection statement, so that's flagged too.
//
// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Conformance Rules, 8
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 18.2, <set connection statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2016(E), 18.3, <disconnect statement>, Conformance Rules, 1
sql_connection_statement:
  connect_statement {
    flag(mut yylex, 'F771')
    $$.v = $1.v as Stmt
  }
| set_connection_statement {
    flag(mut yylex, 'F771')
    $$.v = $1.v as Stmt
  }
| disconnect_statement {
    flag(mut yylex, 'F771')
    $$.v = $1.v as Stmt
  }

sql_session_statement:
  set_schema_statement { $$.v = Stmt($1.v as SetSchemaStatement) }
| set_catalog_statement { $$.v = $1.v as Stmt }

%%
