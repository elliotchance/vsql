%%

// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>
//
// Prepare a statement for execution.

preparable_statement:
  preparable_sql_data_statement { $$.v = $1.v as Stmt }
| preparable_sql_schema_statement { $$.v = $1.v as Stmt }
| preparable_sql_transaction_statement { $$.v = $1.v as Stmt }
| preparable_sql_session_statement { $$.v = $1.v as Stmt }

preparable_sql_data_statement:
  delete_statement_searched { $$.v = $1.v as Stmt }
| insert_statement { $$.v = $1.v as Stmt }
| dynamic_select_statement { $$.v = $1.v as Stmt }
| update_statement_searched { $$.v = $1.v as Stmt }

preparable_sql_schema_statement:
  sql_schema_statement { $$.v = $1.v as Stmt }

preparable_sql_transaction_statement:
  sql_transaction_statement { $$.v = $1.v as Stmt }

preparable_sql_session_statement:
  sql_session_statement { $$.v = $1.v as Stmt }

dynamic_select_statement:
  cursor_specification { $$.v = $1.v as Stmt }

%%
