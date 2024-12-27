%%

column_reference:
  basic_identifier_chain {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!
  }

%%
