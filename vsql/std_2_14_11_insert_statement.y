%%

// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>
//
// Create new rows in a table.

// A <from default> isn't supported, it needs Feature F222, "INSERT statement:
// DEFAULT VALUES clause".
//
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Conformance Rules, 2

insert_statement:
  INSERT INTO insertion_target insert_columns_and_source {
    $$.v = yy_box(Stmt(InsertStatement{
      ...$4.v as InsertStatement
      table_name: $3.v as Identifier
    }))
  }

insertion_target:
  table_name { $$.v = $1.v as Identifier }

insert_columns_and_source:
  from_subquery { $$.v = $1.v }
| from_constructor { $$.v = $1.v }

from_subquery:
  insert_query {
    $$.v = yy_box(InsertStatement{
      query: $1.v as QueryExpression
    })
  }
| override_clause insert_query {
    $$.v = yy_box(InsertStatement{
      overriding: $1.v as string
      query:      $2.v as QueryExpression
    })
  }
| left_paren insert_column_list right_paren insert_query {
    $$.v = yy_box(InsertStatement{
      columns: $2.v as []Identifier
      query:   $4.v as QueryExpression
    })
  }
| left_paren insert_column_list right_paren override_clause insert_query {
    $$.v = yy_box(InsertStatement{
      columns:    $2.v as []Identifier
      overriding: $4.v as string
      query:      $5.v as QueryExpression
    })
  }

// insert_query is the <query expression> of a <from subquery>. It can't only be
// a <table value constructor>, because that's a <from constructor>. Since
// nothing before the first row can tell a <from constructor> from a query that
// starts with VALUES, the rows are parsed the same way for both. So this is the
// same as query_expression, except that the first <query primary> is
// insert_query_primary.
//
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, Syntax Rules, 16
insert_query:
  insert_query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .from_subquery)
    $$.v = $1.v
  }

insert_query_expression:
  query_specification {
    $$.v = yy_box(QueryExpression{
      body: SimpleTable($1.v as QuerySpecification)
    })
  }
| parenthesized_query_expression { $$.v = $1.v }
| insert_query_set_operation {
    $$.v = yy_box(QueryExpression{
      body: $1.v as SimpleTable
    })
  }
| insert_query_intersect_operation {
    $$.v = yy_box(QueryExpression{
      body: $1.v as SimpleTable
    })
  }
| insert_query_body query_expression_clauses {
    $$.v = yy_box(QueryExpression{
      ...$2.v as QueryExpression
      body: $1.v as SimpleTable
    })
  }

insert_query_body:
  insert_query_term { $$.v = $1.v }
| insert_query_set_operation { $$.v = $1.v }

insert_query_set_operation:
  insert_query_body query_set_operator query_term {
    operator := $2.v as QuerySetOperator
    $$.v = yy_box(new_set_operation($1.v as SimpleTable, operator.op, operator.all,
      $3.v as SimpleTable))
  }

insert_query_term:
  insert_query_primary { $$.v = $1.v }
| insert_query_intersect_operation { $$.v = $1.v }

insert_query_intersect_operation:
  insert_query_term intersect_operator query_primary {
    operator := $2.v as QuerySetOperator
    $$.v = yy_box(new_set_operation($1.v as SimpleTable, operator.op, operator.all,
      $3.v as SimpleTable))
  }

insert_query_primary:
  query_specification { $$.v = yy_box(SimpleTable($1.v as QuerySpecification)) }
| parenthesized_query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .query_primary)
    $$.v = yy_box(new_parenthesized_query_expression($1.v as QueryExpression))
  }
| contextually_typed_table_value_constructor {
    // ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Conformance Rules, 5
    flag(mut yylex, 'F661')
    $$.v = yy_box(SimpleTable(row_value_constructors($1.v as []ContextuallyTypedRowValueConstructor)!))
  }

from_constructor:
  contextually_typed_table_value_constructor {
    $$.v = yy_box(InsertStatement{
      values: $1.v as []ContextuallyTypedRowValueConstructor
    })
  }
| override_clause contextually_typed_table_value_constructor {
    $$.v = yy_box(InsertStatement{
      overriding: $1.v as string
      values:     $2.v as []ContextuallyTypedRowValueConstructor
    })
  }
| left_paren insert_column_list right_paren
  contextually_typed_table_value_constructor {
    $$.v = yy_box(InsertStatement{
      columns: $2.v as []Identifier
      values:  $4.v as []ContextuallyTypedRowValueConstructor
    })
  }
| left_paren insert_column_list right_paren override_clause
  contextually_typed_table_value_constructor {
    $$.v = yy_box(InsertStatement{
      columns:    $2.v as []Identifier
      overriding: $4.v as string
      values:     $5.v as []ContextuallyTypedRowValueConstructor
    })
  }

override_clause:
  OVERRIDING USER VALUE {
    flag(mut yylex, 'S043')
    $$.v = 'USER'
  }
| OVERRIDING SYSTEM VALUE {
    flag(mut yylex, 'S043')
    $$.v = 'SYSTEM'
  }

insert_column_list:
  column_name_list { $$.v = $1.v as []Identifier }

%%
