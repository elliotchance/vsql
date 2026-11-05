%%

// A <schema name> is always given, so it always needs F171.
//
// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>, Conformance Rules, 3
schema_definition:
  CREATE SCHEMA schema_name_clause {
    flag(mut yylex, 'F171')
    $$.v = Stmt(SchemaDefinition{$3.v as Identifier, []SchemaElement{}})
  }
| CREATE SCHEMA schema_name_clause schema_elements {
    flag(mut yylex, 'F171')
    $$.v = Stmt(SchemaDefinition{$3.v as Identifier, $4.v as []SchemaElement})
  }

schema_name_clause:
  schema_name { $$.v = $1.v as Identifier }

schema_elements:
  schema_element { $$.v = [$1.v as SchemaElement] }
| schema_elements schema_element {
    $$.v = concat_lists($1.v as []SchemaElement, [$2.v as SchemaElement])
  }

// The other elements aren't statements that are supported yet.
schema_element:
  table_definition { $$.v = SchemaElement($1.v as TableDefinition) }
| sequence_generator_definition {
    $$.v = SchemaElement($1.v as SequenceGeneratorDefinition)
  }

%%
