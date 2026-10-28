%%

identifier:
  actual_identifier { $$.v = $1.v as IdentifierChain }

actual_identifier:
  regular_identifier { $$.v = $1.v as IdentifierChain }

table_name:
  local_or_schema_qualified_name {
    $$.v = new_table_identifier(($1.v as IdentifierChain).identifier)!
  }

// was: [ catalog_name period ] unqualified_schema_name
//
// catalog_name and unqualified_schema_name are both an identifier, so they are
// inlined here and below. Otherwise the parser has to choose one before it sees
// how many parts there are, and a catalog would never be used.
schema_name:
  identifier {
    $$.v = new_schema_identifier(($1.v as IdentifierChain).identifier)!
  }
| identifier period identifier {
    $$.v = new_schema_identifier(($1.v as IdentifierChain).identifier + '.' +
      ($3.v as IdentifierChain).identifier)!
  }

// was: [ schema_name period ] qualified_identifier
schema_qualified_name:
  local_or_schema_qualified_name { $$.v = $1.v as IdentifierChain }

// was: [ local_or_schema_qualifier period ] qualified_identifier
local_or_schema_qualified_name:
  qualified_identifier { $$.v = $1.v as IdentifierChain }
| identifier period qualified_identifier {
    $$.v = IdentifierChain{($1.v as IdentifierChain).identifier + '.' +
      ($3.v as IdentifierChain).identifier}
  }
| identifier period identifier period qualified_identifier {
    $$.v = IdentifierChain{($1.v as IdentifierChain).identifier + '.' +
      ($3.v as IdentifierChain).identifier + '.' + ($5.v as IdentifierChain).identifier}
  }

qualified_identifier:
  identifier { $$.v = $1.v as IdentifierChain }

column_name:
  identifier {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!
  }

correlation_name:
  identifier {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!
  }

constraint_name:
  schema_qualified_name {
    $$.v = new_table_identifier(($1.v as IdentifierChain).identifier)!
  }

sequence_generator_name:
  schema_qualified_name {
    $$.v = new_table_identifier(($1.v as IdentifierChain).identifier)!
  }

%%
