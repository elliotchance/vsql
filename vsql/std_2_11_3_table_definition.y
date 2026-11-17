%%

// ISO/IEC 9075-2:2023, 11.3, <table definition>
//
// Define a persistent base table. A <like clause> is flagged with T171
// (Conformance Rules, 1) and an <as subquery clause> with T172 (Conformance
// Rules, 7).

table_definition:
  CREATE TABLE table_name table_contents_source {
    $$.v = yy_box(TableDefinition{
      ...$4.v as TableDefinition
      table_name: $3.v as Identifier
    })
  }
| CREATE TABLE if_not_exists table_name table_contents_source {
    flag(mut yylex, vsql_create_table_if_not_exists)
    $$.v = yy_box(TableDefinition{
      ...$5.v as TableDefinition
      table_name:    $4.v as Identifier
      if_not_exists: true
    })
  }

// IF NOT EXISTS isn't part of the standard (see the V011 features of the SQL
// Flagger). It can't be an optional (empty) rule of each statement because IF
// can also start the name, such as CREATE TABLE if (x INT). It's only the
// extension when the next token is NOT.
if_not_exists:
  IF NOT EXISTS

// table_contents_source is a TableDefinition that only has its table_elements
// or as_subquery.
table_contents_source:
  table_element_list {
    flag_unique_columns(mut yylex, $1.v as []TableElement)
    $$.v = yy_box(TableDefinition{
      table_elements: $1.v as []TableElement
    })
  }
| as_subquery_clause {
    flag(mut yylex, 'T172')
    $$.v = yy_box(TableDefinition{
      as_subquery: $1.v as AsSubqueryClause
    })
  }

// The query of an <as subquery clause> must be a <table subquery> (in
// parentheses), followed by WITH DATA or WITH NO DATA. Like other databases,
// vsql also allows the query without parentheses (V103-02), and without the
// <with or without data> (V103-03), which is WITH DATA.
as_subquery_clause:
  AS as_subquery_query {
    flag(mut yylex, vsql_create_table_as_with_data)
    $$.v = yy_box(AsSubqueryClause{
      query:     $2.v as QueryExpression
      with_data: true
    })
  }
| AS as_subquery_query with_or_without_data {
    $$.v = yy_box(AsSubqueryClause{
      query:     $2.v as QueryExpression
      with_data: $3.v as bool
    })
  }
| left_paren column_name_list right_paren AS as_subquery_query {
    flag(mut yylex, vsql_create_table_as_with_data)
    $$.v = yy_box(AsSubqueryClause{
      columns:   $2.v as []Identifier
      query:     $5.v as QueryExpression
      with_data: true
    })
  }
| left_paren column_name_list right_paren AS as_subquery_query with_or_without_data {
    $$.v = yy_box(AsSubqueryClause{
      columns:   $2.v as []Identifier
      query:     $5.v as QueryExpression
      with_data: $6.v as bool
    })
  }

as_subquery_query:
  parenthesized_query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .subquery)
    $$.v = $1.v
  }
| nonparenthesized_query_expression {
    flag(mut yylex, vsql_create_table_as_query)
    flag_query_expression(mut yylex, $1.v as QueryExpression, .subquery)
    $$.v = $1.v
  }

with_or_without_data:
  WITH DATA { $$.v = true }
| WITH NO DATA { $$.v = false }

table_element_list:
  left_paren table_elements right_paren { $$.v = $2.v }

table_element:
  column_definition { $$.v = $1.v }
| table_constraint_definition { $$.v = yy_box([$1.v as TableElement]) }
| like_clause {
    flag(mut yylex, 'T171')
    $$.v = yy_box([TableElement($1.v as LikeClause)])
  }

like_clause:
  LIKE table_name { $$.v = yy_box(LikeClause{table_name: $2.v as Identifier}) }

table_elements:
  table_element { $$.v = $1.v }
| table_elements comma table_element {
    $$.v = yy_box(concat_lists($1.v as []TableElement, $3.v as []TableElement))
  }

%%
