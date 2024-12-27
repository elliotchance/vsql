%%

from_clause:
  FROM table_reference_list { $$.v = $2.v as TableReference }

table_reference_list:
  table_reference { $$.v = $1.v as TableReference }

%%
