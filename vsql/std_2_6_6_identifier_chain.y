%%

identifier_chain:
  identifier { $$.v = $1.v }
| identifier_chain period identifier {
    $$.v = yy_box(IdentifierChain{
      ($1.v as IdentifierChain).identifier + '.' + ($3.v as IdentifierChain).identifier
    })
  }

basic_identifier_chain:
  identifier_chain { $$.v = $1.v }

%%
