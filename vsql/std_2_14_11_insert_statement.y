%%

insert_statement:
  INSERT INTO insertion_target insert_columns_and_source {
    stmt := $4.v as InsertStatement
    $$.v = Stmt(InsertStatement{$3.v as Identifier, stmt.columns, stmt.values})
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

insert_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

%%
