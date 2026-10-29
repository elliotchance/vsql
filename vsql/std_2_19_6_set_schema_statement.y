%%

set_schema_statement:
  SET schema_name_characteristic {
    flag(mut yylex, 'F761')
    $$.v = SetSchemaStatement{$2.v as ValueSpecification}
  }

schema_name_characteristic:
  SCHEMA value_specification { $$.v = $2.v }

%%
