%%

// ISO/IEC 9075-2:2023, 6.7, <column reference>
//
// Reference a column.

column_reference:
  basic_identifier_chain {
    parsed_sort_key_part(mut yylex, .column_reference)
    $$.v = yy_box(new_column_identifier(($1.v as IdentifierChain).identifier)!)
  }

%%
