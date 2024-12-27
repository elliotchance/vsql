%%

identifier_chain:
  identifier { $$.v = $1.v as IdentifierChain }
| identifier period identifier {
    $$.v = IdentifierChain{
      ($1.v as IdentifierChain).identifier + '.' + ($3.v as IdentifierChain).identifier
    }
  }

basic_identifier_chain:
  identifier_chain { $$.v = $1.v as IdentifierChain }

%%
