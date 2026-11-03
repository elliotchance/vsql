%%

// ISO/IEC 9075-2:2016(E), 7.5, <from clause>
//
// Specify a table derived from one or more tables.

from_clause:
  FROM table_reference_list { $$.v = $2.v as TableReference }

table_reference_list:
  table_reference { $$.v = $1.v as TableReference }
| table_reference_list comma table_reference {
    $$.v = TableReference(new_cross_join($1.v as TableReference,
      $3.v as TableReference))
  }

%%
