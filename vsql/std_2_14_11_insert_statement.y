%%

insert_statement:
  INSERT INTO insertion_target insert_columns_and_source {
    $$.v = Stmt(InsertStatement{
      ...$4.v as InsertStatement
      table_name: $3.v as Identifier
    })
  }

insertion_target:
  table_name { $$.v = $1.v as Identifier }

insert_columns_and_source:
  from_constructor { $$.v = $1.v as InsertStatement }

from_constructor:
  left_paren insert_column_list right_paren
  contextually_typed_table_value_constructor {
    $$.v = InsertStatement{
      columns: $2.v as []Identifier
      values:  $4.v as []ContextuallyTypedRowValueConstructor
    }
  }
| left_paren insert_column_list right_paren override_clause
  contextually_typed_table_value_constructor {
    $$.v = InsertStatement{
      columns:    $2.v as []Identifier
      overriding: $4.v as string
      values:     $5.v as []ContextuallyTypedRowValueConstructor
    }
  }

override_clause:
  OVERRIDING USER VALUE { $$.v = 'USER' }
| OVERRIDING SYSTEM VALUE { $$.v = 'SYSTEM' }

insert_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

%%
