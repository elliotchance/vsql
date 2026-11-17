%%

// ISO/IEC 9075-2:2023, 11.21, <drop identity property clause>, Conformance Rules, 1
drop_identity_property_clause:
  DROP IDENTITY {
    flag(mut yylex, 'F384')
    $$.v = yy_box(DropIdentityPropertyClause{})
  }

%%
