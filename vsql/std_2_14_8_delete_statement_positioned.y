%%

// ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>
//
// Delete a row of a table.

delete_statement_positioned:
  DELETE FROM target_table target_correlation_name WHERE CURRENT OF cursor_name {
    flag(mut yylex, vsql_delete_positioned)
    $$.v = yy_box(Stmt(DeleteStatementPositioned{$3.v as Identifier,
      $4.v as Identifier, $8.v as string}))
  }

target_table:
  table_name { $$.v = $1.v as Identifier }

// The optional [ [ AS ] <correlation name> ] of the target table of a DELETE or
// UPDATE. Unlike a <table primary> it can't have a derived column list.
//
// ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>, Format
// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>, Format
// ISO/IEC 9075-2:2016(E), 14.13, <update statement: positioned>, Format
// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, Format

target_correlation_name:
  { $$.v = Identifier{} }
| correlation_name { $$.v = $1.v as Identifier }
| AS correlation_name { $$.v = $2.v as Identifier }

%%
