%%

set_schema_statement:
  SET schema_name_characteristic {
    $$.v = SetSchemaStatement{$2.v as ValueSpecification}
  }

schema_name_characteristic:
  SCHEMA value_specification { $$.v = $2.v }

%%
