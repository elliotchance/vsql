%%

// A <schema name> is always given, so it always needs F171.
//
// ISO/IEC 9075-2:2023, 11.1, <schema definition>, Conformance Rules, 3
schema_definition:
  CREATE SCHEMA schema_name_clause {
    flag(mut yylex, 'F171')
    $$.v = yy_box(Stmt(SchemaDefinition{
      schema_name: $3.v as Identifier
    }))
  }
| CREATE SCHEMA schema_name_clause schema_elements {
    flag(mut yylex, 'F171')
    $$.v = yy_box(Stmt(SchemaDefinition{
      schema_name: $3.v as Identifier
      elements:    $4.v as []SchemaElement
    }))
  }
| CREATE SCHEMA if_not_exists schema_name_clause {
    flag(mut yylex, 'F171')
    flag(mut yylex, vsql_create_schema_if_not_exists)
    $$.v = yy_box(Stmt(SchemaDefinition{
      schema_name:   $4.v as Identifier
      if_not_exists: true
    }))
  }
| CREATE SCHEMA if_not_exists schema_name_clause schema_elements {
    flag(mut yylex, 'F171')
    flag(mut yylex, vsql_create_schema_if_not_exists)
    $$.v = yy_box(Stmt(SchemaDefinition{
      schema_name:   $4.v as Identifier
      elements:      $5.v as []SchemaElement
      if_not_exists: true
    }))
  }

schema_name_clause:
  schema_name { $$.v = $1.v }

schema_elements:
  schema_element { $$.v = yy_box([$1.v as SchemaElement]) }
| schema_elements schema_element {
    $$.v = yy_box(concat_lists($1.v as []SchemaElement, [$2.v as SchemaElement]))
  }

// The other elements aren't statements that are supported yet.
schema_element:
  table_definition { $$.v = yy_box(SchemaElement($1.v as TableDefinition)) }
| sequence_generator_definition {
    $$.v = yy_box(SchemaElement($1.v as SequenceGeneratorDefinition))
  }

%%
