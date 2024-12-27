%%

// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>
//
// Define all of the SQL-statements that are <SQL procedure statement>s.

sql_schema_statement:
  sql_schema_definition_statement { $$.v = $1.v as Stmt }
| sql_schema_manipulation_statement { $$.v = $1.v as Stmt }

sql_schema_definition_statement:
  schema_definition { $$.v = $1.v as Stmt }
| table_definition { $$.v = $1.v as Stmt }
| sequence_generator_definition { $$.v = Stmt($1.v as SequenceGeneratorDefinition) }

sql_schema_manipulation_statement:
  drop_schema_statement { $$.v = $1.v as Stmt }
| drop_table_statement { $$.v = $1.v as Stmt }
| alter_sequence_generator_statement { $$.v = Stmt($1.v as AlterSequenceGeneratorStatement) }
| drop_sequence_generator_statement { $$.v = $1.v as Stmt }

sql_transaction_statement:
  start_transaction_statement { $$.v = $1.v as Stmt }
| commit_statement { $$.v = $1.v as Stmt }
| rollback_statement { $$.v = $1.v as Stmt }

sql_session_statement:
  set_schema_statement { $$.v = Stmt($1.v as SetSchemaStatement) }
| set_catalog_statement { $$.v = $1.v as Stmt }

%%
