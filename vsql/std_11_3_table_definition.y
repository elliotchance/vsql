%%

table_definition:
  CREATE TABLE table_name table_contents_source {
    $$.v = Stmt(TableDefinition{$3.v as Identifier, $4.v as []TableElement})
  }

table_contents_source:
  table_element_list { $$.v = $1.v as []TableElement }

table_element_list:
  left_paren table_elements right_paren { $$.v = $2.v as []TableElement }

table_element:
  column_definition { $$.v = $1.v as TableElement }
| table_constraint_definition { $$.v = $1.v as TableElement }

table_elements:
  table_element { $$.v = [$1.v as TableElement] }
| table_elements comma table_element {
    $$.v = append_list($1.v as []TableElement, $3.v as TableElement)
  }

%%
