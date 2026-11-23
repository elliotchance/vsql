%%

// ISO/IEC 9075-2:2023, 14.11, <insert statement>
//
// Create new rows in a table.

insert_statement:
  INSERT INTO insertion_target insert_columns_and_source {
    $$.v = yy_box(Stmt(InsertStatement{
      ...$4.v as InsertStatement
      table_name: $3.v as Identifier
    }))
  }
| INSERT INTO insertion_target insert_columns_and_source on_conflict_clause {
    flag(mut yylex, vsql_insert_on_conflict)
    $$.v = yy_box(Stmt(InsertStatement{
      ...$4.v as InsertStatement
      table_name:  $3.v as Identifier
      on_conflict: $5.v as OnConflict
    }))
  }

// ON CONFLICT is a vsql extension (V119-02), see OnConflict. DO UPDATE needs a
// conflict target.
on_conflict_clause:
  OPERATOR_ON_CONFLICT OPERATOR_DO OPERATOR_NOTHING {
    $$.v = yy_box(OnConflict{})
  }
| OPERATOR_ON_CONFLICT conflict_target OPERATOR_DO OPERATOR_NOTHING {
    $$.v = $2.v
  }
| OPERATOR_ON_CONFLICT conflict_target OPERATOR_DO UPDATE SET set_clause_list {
    $$.v = yy_box(OnConflict{
      ...$2.v as OnConflict
      do_update: true
      set:       $6.v as []SetClause
    })
  }
| OPERATOR_ON_CONFLICT conflict_target OPERATOR_DO UPDATE SET set_clause_list
  WHERE search_condition {
    $$.v = yy_box(OnConflict{
      ...$2.v as OnConflict
      do_update: true
      set:       $6.v as []SetClause
      condition: $8.v as BooleanValueExpression
    })
  }

conflict_target:
  left_paren column_name_list right_paren {
    $$.v = yy_box(OnConflict{
      columns: $2.v as []Identifier
    })
  }
| ON CONSTRAINT identifier {
    $$.v = yy_box(OnConflict{
      constraint_name: new_table_identifier(($3.v as IdentifierChain).identifier)!.entity_name
    })
  }

// RETURNING is a vsql extension (V119-01), see returning_query.

insert_statement_returning:
  insert_statement OPERATOR_RETURNING select_list {
    flag(mut yylex, vsql_insert_returning)
    $$.v = yy_box(with_returning($1.v as Stmt, $3.v as SelectList))
  }

insertion_target:
  table_name { $$.v = $1.v }

insert_columns_and_source:
  from_subquery { $$.v = $1.v }
| from_constructor { $$.v = $1.v }
| from_default { $$.v = $1.v }

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
// ISO/IEC 9075-2:2023, 14.11, <insert statement>, Syntax Rules, 18
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
| explicit_table {
    // ISO/IEC 9075-2:2023, 7.17, <query expression>, Conformance Rules, 6
    flag(mut yylex, 'F661')
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
| explicit_table {
    // ISO/IEC 9075-2:2023, 7.17, <query expression>, Conformance Rules, 6
    flag(mut yylex, 'F661')
    $$.v = yy_box(SimpleTable($1.v as QuerySpecification))
  }
| contextually_typed_table_value_constructor {
    // ISO/IEC 9075-2:2023, 7.17, <query expression>, Conformance Rules, 5
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

// A <from default> inserts one row where every column gets its default.
from_default:
  DEFAULT VALUES {
    // ISO/IEC 9075-2:2023, 14.11, <insert statement>, Conformance Rules, 2
    flag(mut yylex, 'F222')
    $$.v = yy_box(InsertStatement{
      from_default: true
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
  column_name_list { $$.v = $1.v }

%%
