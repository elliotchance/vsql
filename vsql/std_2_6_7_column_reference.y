%%

// ISO/IEC 9075-2:2016(E), 6.7, <column reference>
//
// Reference a column.

column_reference:
  basic_identifier_chain {
    parsed_sort_key_part(mut yylex, .column_reference)
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!
  }

%%
