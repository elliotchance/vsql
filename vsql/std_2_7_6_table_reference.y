%%

// ISO/IEC 9075-2:2023(E), 7.6, <table reference>
//
// Reference a table.

table_reference:
  table_factor { $$.v = yy_box(TableReference($1.v as TablePrimary)) }
| joined_table { $$.v = yy_box(TableReference($1.v as QualifiedJoin)) }
| parenthesized_joined_table {
    $$.v = yy_box(TableReference($1.v as QualifiedJoin))
  }

parenthesized_joined_table:
  left_paren parenthesized_joined_table right_paren {
    $$.v = $2.v
  }
| left_paren joined_table right_paren { $$.v = $2.v }

// Without a join type, it's INNER.
//
// ISO/IEC 9075-2:2023(E), 7.10, <joined table>, Syntax Rules, 5

qualified_join:
  table_reference JOIN table_reference join_specification {
    $$.v = yy_box(new_qualified_join($1.v as TableReference, JoinType.inner,
      $3.v as TableReference, $4.v as JoinSpecification))
  }
| table_reference join_type JOIN table_reference join_specification {
    $$.v = yy_box(new_qualified_join($1.v as TableReference, $2.v as JoinType,
      $4.v as TableReference, $5.v as JoinSpecification))
  }

table_factor:
  table_primary { $$.v = $1.v }

table_primary:
  table_or_query_name { 
    $$.v = yy_box(TablePrimary{
      body: $1.v as Identifier
    })
  }
| table_or_query_name correlation_or_recognition {
    $$.v = yy_box(TablePrimary{
      body:        $1.v as Identifier
      correlation: $2.v as Correlation
    })
  }
| derived_table {
    // ISO/IEC 9075-2:2023(E), 7.6, <table reference>, Format
    flag(mut yylex, vsql_derived_table_without_name)
    $$.v = $1.v
  }
| derived_table correlation_or_recognition {
    $$.v = yy_box(TablePrimary{
      body:        ($1.v as TablePrimary).body
      correlation: $2.v as Correlation
    })
  }

correlation_or_recognition:
  correlation_name {
    $$.v = yy_box(Correlation{
      name: $1.v as Identifier
    })
  }
| AS correlation_name {
    $$.v = yy_box(Correlation{
      name: $2.v as Identifier
    })
  }
| correlation_name parenthesized_derived_column_list {
    $$.v = yy_box(Correlation{
      name:    $1.v as Identifier
      columns: $2.v as []Identifier
    })
  }
| AS correlation_name parenthesized_derived_column_list {
    $$.v = yy_box(Correlation{
      name:    $2.v as Identifier
      columns: $3.v as []Identifier
    })
  }
// The lexer can't tell that this ILIKE is a name, since it's between a value and
// a left parenthesis (see is_ilike_operator). It can't be an operator here.
| OPERATOR_ILIKE parenthesized_derived_column_list {
    $$.v = yy_box(Correlation{
      name:    new_column_identifier('ILIKE')!
      columns: $2.v as []Identifier
    })
  }

derived_table:
  table_subquery {
    // ISO/IEC 9075-2:2023(E), 7.6, <table reference>, Conformance Rules, 6
    flag(mut yylex, 'F591')
    $$.v = $1.v
  }

table_or_query_name:
  table_name { $$.v = $1.v }

derived_column_list:
  column_name_list { $$.v = $1.v }

column_name_list:
  column_name { $$.v = yy_box([$1.v as Identifier]) }
| column_name_list comma column_name {
    $$.v = yy_box(append_list($1.v as []Identifier, $3.v as Identifier))
  }

parenthesized_derived_column_list:
  left_paren derived_column_list right_paren { $$.v = $2.v }

%%
