%%

// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>
//
// Update rows of a table.

// There's no <correlation name> (#793). ONLY needs Feature S111, "ONLY in query
// expressions", and FOR PORTION OF needs Feature T181, "Application-time period
// tables". Without WHERE, every row is updated.
//
// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, Syntax Rules, 5

update_statement_searched:
  UPDATE target_table SET set_clause_list {
	  $$.v = Stmt(UpdateStatementSearched{$2.v as Identifier,
      $4.v as []SetClause, none, none})
  }
| UPDATE target_table SET set_clause_list WHERE search_condition {
    $$.v = Stmt(UpdateStatementSearched{$2.v as Identifier,
      $4.v as []SetClause, $6.v as BooleanValueExpression, none})
  }

%%
