%%

// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>
//
// Prepare a statement for execution.

preparable_statement:
  preparable_sql_data_statement { $$.v = $1.v }
| preparable_sql_schema_statement { $$.v = $1.v }
| preparable_sql_transaction_statement { $$.v = $1.v }
| preparable_sql_session_statement { $$.v = $1.v }

preparable_sql_data_statement:
  delete_statement_searched { $$.v = $1.v }
| insert_statement { $$.v = $1.v }
| merge_statement { $$.v = $1.v }
| dynamic_select_statement { $$.v = $1.v }
| update_statement_searched { $$.v = $1.v }
| delete_statement_returning { $$.v = $1.v }
| insert_statement_returning { $$.v = $1.v }
| update_statement_returning { $$.v = $1.v }

preparable_sql_schema_statement:
  sql_schema_statement { $$.v = $1.v }

preparable_sql_transaction_statement:
  sql_transaction_statement { $$.v = $1.v }

preparable_sql_session_statement:
  sql_session_statement { $$.v = $1.v }

dynamic_select_statement:
  cursor_specification { $$.v = $1.v }

%%
