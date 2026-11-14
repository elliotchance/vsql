%%

identifier:
  actual_identifier { $$.v = $1.v }

actual_identifier:
  regular_identifier { $$.v = $1.v }

table_name:
  local_or_schema_qualified_name {
    $$.v = yy_box(new_table_identifier(($1.v as IdentifierChain).identifier)!)
  }

// was: [ catalog_name period ] unqualified_schema_name
//
// catalog_name and unqualified_schema_name are both an identifier, so they are
// inlined here and below. Otherwise the parser has to choose one before it sees
// how many parts there are, and a catalog would never be used.
schema_name:
  identifier {
    $$.v = yy_box(new_schema_identifier(($1.v as IdentifierChain).identifier)!)
  }
| identifier period identifier {
    flag(mut yylex, 'F651')
    $$.v = yy_box(new_schema_identifier(($1.v as IdentifierChain).identifier + '.' +
      ($3.v as IdentifierChain).identifier)!)
  }

// was: [ schema_name period ] qualified_identifier
schema_qualified_name:
  local_or_schema_qualified_name { $$.v = $1.v }

// was: [ local_or_schema_qualifier period ] qualified_identifier
local_or_schema_qualified_name:
  qualified_identifier { $$.v = $1.v }
| identifier period qualified_identifier {
    $$.v = yy_box(IdentifierChain{($1.v as IdentifierChain).identifier + '.' +
      ($3.v as IdentifierChain).identifier})
  }
| identifier period identifier period qualified_identifier {
    flag(mut yylex, 'F651')
    $$.v = yy_box(IdentifierChain{($1.v as IdentifierChain).identifier + '.' +
      ($3.v as IdentifierChain).identifier + '.' + ($5.v as IdentifierChain).identifier})
  }

qualified_identifier:
  identifier { $$.v = $1.v }

column_name:
  identifier {
    $$.v = yy_box(new_column_identifier(($1.v as IdentifierChain).identifier)!)
  }

correlation_name:
  identifier {
    $$.v = yy_box(new_column_identifier(($1.v as IdentifierChain).identifier)!)
  }

// Every <constraint name> needs F491, which includes the one in a <constraint
// name definition>.
//
// ISO/IEC 9075-2:2023, 10.8, <constraint name definition> and <constraint characteristics>, Conformance Rules, 2
constraint_name:
  schema_qualified_name {
    flag(mut yylex, 'F491')
    $$.v = yy_box(new_table_identifier(($1.v as IdentifierChain).identifier)!)
  }

sequence_generator_name:
  schema_qualified_name {
    $$.v = yy_box(new_table_identifier(($1.v as IdentifierChain).identifier)!)
  }

connection_name:
  simple_value_specification { $$.v = $1.v }

sql_server_name:
  simple_value_specification { $$.v = $1.v }

connection_user_name:
  simple_value_specification { $$.v = $1.v }

// was: local_qualified_name
cursor_name:
  identifier {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!.sub_entity_name
  }

%%
