%%

// A <schema name> is always given, so it always needs F171.
//
// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>, Conformance Rules, 3
schema_definition:
  CREATE SCHEMA schema_name_clause {
    flag(mut yylex, 'F171')
    $$.v = Stmt(SchemaDefinition{$3.v as Identifier})
  }

schema_name_clause:
  schema_name { $$.v = $1.v as Identifier }

%%
