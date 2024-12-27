%%

// ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>
//
// Delete a row of a table.

target_table:
  table_name { $$.v = $1.v as Identifier }

%%
