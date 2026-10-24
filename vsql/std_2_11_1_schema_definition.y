%%

schema_definition:
  CREATE SCHEMA schema_name_clause {
    $$.v = Stmt(SchemaDefinition{$3.v as Identifier})
  }

schema_name_clause:
  schema_name { $$.v = $1.v as Identifier }

%%
