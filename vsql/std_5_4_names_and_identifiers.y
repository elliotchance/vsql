%%

identifier:
  actual_identifier { $$.v = $1.v as IdentifierChain }

actual_identifier:
  regular_identifier { $$.v = $1.v as IdentifierChain }

table_name:
  local_or_schema_qualified_name {
    $$.v = new_table_identifier(($1.v as IdentifierChain).identifier)!
  }

schema_name:
  catalog_name period unqualified_schema_name   {
    $$.v = new_schema_identifier(($1.v as IdentifierChain).str() + '.' +
      ($3.v as Identifier).str())!
  }
| unqualified_schema_name { $$.v = $1.v as Identifier }

unqualified_schema_name:
  identifier {
    $$.v = new_schema_identifier(($1.v as IdentifierChain).identifier)!
  }

catalog_name:
  identifier { $$.v = $1.v as IdentifierChain }

schema_qualified_name:
  qualified_identifier { $$.v = $1.v as IdentifierChain }
| schema_name period qualified_identifier   {
    $$.v = IdentifierChain{($1.v as Identifier).schema_name + '.' +
      ($3.v as IdentifierChain).str()}
  }

local_or_schema_qualified_name:
  qualified_identifier { $$.v = $1.v as IdentifierChain }
| local_or_schema_qualifier period qualified_identifier {
    $$.v = IdentifierChain{($1.v as Identifier).str() + '.' +
      ($3.v as IdentifierChain).str()}
  }

local_or_schema_qualifier:
  schema_name { $$.v = $1.v as Identifier }

qualified_identifier:
  identifier { $$.v = $1.v as IdentifierChain }

column_name:
  identifier {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!
  }

host_parameter_name:
  colon identifier {
    $$.v = GeneralValueSpecification(HostParameterName{
      ($2.v as IdentifierChain).identifier}
    )
  }

correlation_name:
  identifier {
    $$.v = new_column_identifier(($1.v as IdentifierChain).identifier)!
  }

sequence_generator_name:
  schema_qualified_name {
    $$.v = new_table_identifier(($1.v as IdentifierChain).identifier)!
  }

%%
