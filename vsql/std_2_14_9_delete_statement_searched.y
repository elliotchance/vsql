%%

// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>
//
// Delete rows of a table.

// There's no <correlation name> (#793). ONLY needs Feature S111, "ONLY in query
// expressions", and FOR PORTION OF needs Feature T181, "Application-time period
// tables". Without WHERE, every row is deleted.
//
// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>, Syntax Rules, 5

delete_statement_searched:
  DELETE FROM target_table {
    $$.v = Stmt(DeleteStatementSearched{$3.v as Identifier, none, none})
  }
| DELETE FROM target_table WHERE search_condition {
    $$.v = Stmt(DeleteStatementSearched{
      $3.v as Identifier
      $5.v as BooleanValueExpression
      none
    })
  }

%%
