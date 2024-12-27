%%

table_reference:
  table_factor { $$.v = TableReference($1.v as TablePrimary) }
| joined_table { $$.v = TableReference($1.v as QualifiedJoin) }

qualified_join:
  table_reference JOIN table_reference join_specification {
    $$.v = QualifiedJoin{
      $1.v as TableReference
      'INNER'
      $3.v as TableReference
      $4.v as BooleanValueExpression
    }
  }
| table_reference join_type JOIN table_reference join_specification {
    $$.v = QualifiedJoin{
      $1.v as TableReference
      $2.v as string
      $4.v as TableReference
      $5.v as BooleanValueExpression
    }
  }

table_factor:
  table_primary { $$.v = $1.v as TablePrimary }

table_primary:
  table_or_query_name { 
    $$.v = TablePrimary{
      body: $1.v as Identifier
    }
  }
| derived_table { $$.v = $1.v as TablePrimary }
| derived_table correlation_or_recognition {
    $$.v = TablePrimary{
      body:        ($1.v as TablePrimary).body
      correlation: $2.v as Correlation
    }
  }

correlation_or_recognition:
  correlation_name {
    $$.v = Correlation{
      name: $1.v as Identifier
    }
  }
| AS correlation_name {
    $$.v = Correlation{
      name: $2.v as Identifier
    }
  }
| correlation_name parenthesized_derived_column_list {
    $$.v = Correlation{
      name:    $1.v as Identifier
      columns: $2.v as []Identifier
    }
  }
| AS correlation_name parenthesized_derived_column_list {
    $$.v = Correlation{
      name:    $2.v as Identifier
      columns: $3.v as []Identifier
    }
  }

derived_table:
  table_subquery { $$.v = $1.v as TablePrimary }

table_or_query_name:
  table_name { $$.v = $1.v as Identifier }

derived_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

column_name_list:
  column_name { $$.v = [$1.v as Identifier] }
| column_name_list comma column_name {
    $$.v = append_list($1.v as []Identifier, $3.v as Identifier)
  }

parenthesized_derived_column_list:
  left_paren derived_column_list right_paren { $$.v = $2.v }

%%
