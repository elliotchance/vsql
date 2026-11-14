%%

// ISO/IEC 9075-2:2023(E), 14.9, <delete statement: searched>
//
// Delete rows of a table.

// ONLY needs Feature S111, "ONLY in query
// expressions", and FOR PORTION OF needs Feature T181, "Application-time period
// tables". Without WHERE, every row is deleted.
//
// ISO/IEC 9075-2:2023(E), 14.9, <delete statement: searched>, Syntax Rules, 5

delete_statement_searched:
  DELETE FROM target_table target_correlation_name {
    $$.v = yy_box(Stmt(DeleteStatementSearched{$3.v as Identifier, $4.v as Identifier,
      none, none}))
  }
| DELETE FROM target_table target_correlation_name WHERE search_condition {
    $$.v = yy_box(Stmt(DeleteStatementSearched{
      $3.v as Identifier
      $4.v as Identifier
      $6.v as BooleanValueExpression
      none
    }))
  }

%%
