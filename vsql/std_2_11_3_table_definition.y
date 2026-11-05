%%

table_definition:
  CREATE TABLE table_name table_contents_source {
    flag_unique_columns(mut yylex, $4.v as []TableElement)
    $$.v = TableDefinition{
      table_name:     $3.v as Identifier
      table_elements: $4.v as []TableElement
    }
  }
| CREATE TABLE if_not_exists table_name table_contents_source {
    flag(mut yylex, vsql_create_table_if_not_exists)
    flag_unique_columns(mut yylex, $5.v as []TableElement)
    $$.v = TableDefinition{
      table_name:     $4.v as Identifier
      table_elements: $5.v as []TableElement
      if_not_exists:  true
    }
  }

// IF NOT EXISTS isn't part of the standard (see the V011 features of the SQL
// Flagger). It can't be an optional (empty) rule of each statement because IF
// can also start the name, such as CREATE TABLE if (x INT). It's only the
// extension when the next token is NOT.
if_not_exists:
  IF NOT EXISTS

table_contents_source:
  table_element_list { $$.v = $1.v as []TableElement }

table_element_list:
  left_paren table_elements right_paren { $$.v = $2.v as []TableElement }

table_element:
  column_definition { $$.v = $1.v as []TableElement }
| table_constraint_definition { $$.v = [$1.v as TableElement] }

table_elements:
  table_element { $$.v = $1.v as []TableElement }
| table_elements comma table_element {
    $$.v = concat_lists($1.v as []TableElement, $3.v as []TableElement)
  }

%%
