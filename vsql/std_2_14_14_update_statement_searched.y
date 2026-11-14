%%

// ISO/IEC 9075-2:2023(E), 14.14, <update statement: searched>
//
// Update rows of a table.

// ONLY needs Feature S111, "ONLY in query
// expressions", and FOR PORTION OF needs Feature T181, "Application-time period
// tables". Without WHERE, every row is updated.
//
// ISO/IEC 9075-2:2023(E), 14.14, <update statement: searched>, Syntax Rules, 5

update_statement_searched:
  UPDATE target_table target_correlation_name SET set_clause_list {
	  $$.v = yy_box(Stmt(UpdateStatementSearched{$2.v as Identifier, $3.v as Identifier,
      $5.v as []SetClause, none, none}))
  }
| UPDATE target_table target_correlation_name SET set_clause_list WHERE search_condition {
    $$.v = yy_box(Stmt(UpdateStatementSearched{$2.v as Identifier, $3.v as Identifier,
      $5.v as []SetClause, $7.v as BooleanValueExpression, none}))
  }

%%
