%%

// ISO/IEC 9075-2:2016(E), 6.7, <column reference>
//
// Reference a column.

column_reference:
  basic_identifier_chain {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!
  }

%%
