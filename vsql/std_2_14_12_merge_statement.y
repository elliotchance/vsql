%%

// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>
//
// Conditionally update rows of a table, or insert new rows into a table.

// The source can't be a <joined table>, so it's a <table factor>.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Syntax Rules, 11
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Conformance Rules, 4 and 5
merge_statement:
  MERGE INTO target_table target_correlation_name USING table_factor
  ON search_condition merge_operation_specification {
    clauses := $9.v as []MergeWhenClause
    flag(mut yylex, 'F312')
    if clauses.filter(it.matched).len > 1 || clauses.filter(!it.matched).len > 1 {
      flag(mut yylex, 'F313')
    }
    $$.v = yy_box(Stmt(MergeStatement{
      table_name:       $3.v as Identifier
      correlation_name: $4.v as Identifier
      source:           $6.v as TablePrimary
      condition:        $8.v as BooleanValueExpression
      clauses:          clauses
    }))
  }

merge_operation_specification:
  merge_when_clause { $$.v = yy_box([$1.v as MergeWhenClause]) }
| merge_operation_specification merge_when_clause {
    $$.v = yy_box(append_list($1.v as []MergeWhenClause, $2.v as MergeWhenClause))
  }

merge_when_clause:
  merge_when_matched_clause { $$.v = $1.v }
| merge_when_not_matched_clause { $$.v = $1.v }

// A search condition after AND needs Feature F313.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Conformance Rules, 6
merge_when_matched_clause:
  WHEN MATCHED THEN merge_update_or_delete_specification { $$.v = $4.v }
| WHEN MATCHED AND search_condition THEN merge_update_or_delete_specification {
    flag(mut yylex, 'F313')
    $$.v = yy_box(MergeWhenClause{
      ...$6.v as MergeWhenClause
      condition: $4.v as BooleanValueExpression
    })
  }

merge_when_not_matched_clause:
  WHEN NOT MATCHED THEN merge_insert_specification { $$.v = $5.v }
| WHEN NOT MATCHED AND search_condition THEN merge_insert_specification {
    flag(mut yylex, 'F313')
    $$.v = yy_box(MergeWhenClause{
      ...$7.v as MergeWhenClause
      condition: $5.v as BooleanValueExpression
    })
  }

merge_update_or_delete_specification:
  merge_update_specification { $$.v = $1.v }
| merge_delete_specification { $$.v = $1.v }

// DELETE needs Feature F314.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Conformance Rules, 7
merge_delete_specification:
  DELETE {
    flag(mut yylex, 'F314')
    $$.v = yy_box(MergeWhenClause{
      matched: true
      delete:  true
    })
  }

merge_update_specification:
  UPDATE SET set_clause_list {
    $$.v = yy_box(MergeWhenClause{
      matched: true
      set:     $3.v as []SetClause
    })
  }

merge_insert_specification:
  INSERT VALUES merge_insert_value_list {
    $$.v = yy_box(MergeWhenClause{
      values: $3.v as []ContextuallyTypedRowValueConstructorElement
    })
  }
| INSERT override_clause VALUES merge_insert_value_list {
    $$.v = yy_box(MergeWhenClause{
      overriding: $2.v as string
      values:     $4.v as []ContextuallyTypedRowValueConstructorElement
    })
  }
| INSERT left_paren insert_column_list right_paren VALUES
  merge_insert_value_list {
    $$.v = yy_box(MergeWhenClause{
      columns: $3.v as []Identifier
      values:  $6.v as []ContextuallyTypedRowValueConstructorElement
    })
  }
| INSERT left_paren insert_column_list right_paren override_clause VALUES
  merge_insert_value_list {
    $$.v = yy_box(MergeWhenClause{
      columns:    $3.v as []Identifier
      overriding: $5.v as string
      values:     $7.v as []ContextuallyTypedRowValueConstructorElement
    })
  }

merge_insert_value_list:
  left_paren contextually_typed_row_value_constructor_element_list right_paren {
    $$.v = $2.v
  }

%%
