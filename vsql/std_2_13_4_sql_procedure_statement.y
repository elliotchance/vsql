%%

// ISO/IEC 9075-2:2023, 13.4, <SQL procedure statement>
//
// Define all of the SQL-statements that are <SQL procedure statement>s.

// Only the <SQL data statement>s that aren't also a <preparable statement> are
// here. They use a standing cursor, which can only be declared outside of an
// SQL-client module as a vsql extension (see declare_cursor).
sql_data_statement:
  open_statement { $$.v = $1.v }
| fetch_statement { $$.v = $1.v }
| close_statement { $$.v = $1.v }
| delete_statement_positioned { $$.v = $1.v }
| update_statement_positioned { $$.v = $1.v }

sql_schema_statement:
  sql_schema_definition_statement { $$.v = $1.v }
| sql_schema_manipulation_statement { $$.v = $1.v }

sql_schema_definition_statement:
  schema_definition { $$.v = $1.v }
| table_definition { $$.v = yy_box(Stmt($1.v as TableDefinition)) }
| sequence_generator_definition { $$.v = yy_box(Stmt($1.v as SequenceGeneratorDefinition)) }
| create_index_statement { $$.v = $1.v }

sql_schema_manipulation_statement:
  drop_schema_statement { $$.v = $1.v }
| alter_table_statement { $$.v = $1.v }
| drop_table_statement { $$.v = $1.v }
| alter_sequence_generator_statement { $$.v = yy_box(Stmt($1.v as AlterSequenceGeneratorStatement)) }
| drop_sequence_generator_statement { $$.v = $1.v }
| drop_index_statement { $$.v = $1.v }

sql_transaction_statement:
  start_transaction_statement { $$.v = $1.v }
| commit_statement { $$.v = $1.v }
| rollback_statement { $$.v = $1.v }
| set_transaction_statement { $$.v = $1.v }
| savepoint_statement { $$.v = $1.v }
| release_savepoint_statement { $$.v = $1.v }
| set_constraints_mode_statement { $$.v = $1.v }

// A <connection name> is only in a connection statement, so that's flagged too.
//
// ISO/IEC 9075-2:2023, 5.4, Names and identifiers, Conformance Rules, 8
// ISO/IEC 9075-2:2023, 18.1, <connect statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2023, 18.2, <set connection statement>, Conformance Rules, 1
// ISO/IEC 9075-2:2023, 18.3, <disconnect statement>, Conformance Rules, 1
sql_connection_statement:
  connect_statement {
    flag(mut yylex, 'F771')
    $$.v = $1.v
  }
| set_connection_statement {
    flag(mut yylex, 'F771')
    $$.v = $1.v
  }
| disconnect_statement {
    flag(mut yylex, 'F771')
    $$.v = $1.v
  }

sql_session_statement:
  set_schema_statement { $$.v = yy_box(Stmt($1.v as SetSchemaStatement)) }
| set_session_characteristics_statement { $$.v = $1.v }
| set_names_statement { $$.v = $1.v }
| set_catalog_statement { $$.v = $1.v }

%%
