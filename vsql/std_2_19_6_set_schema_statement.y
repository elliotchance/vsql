%%

// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, Conformance Rules, 1

set_schema_statement:
  SET schema_name_characteristic {
    flag(mut yylex, 'F761')
    $$.v = SetSchemaStatement{$2.v as ValueSpecification}
  }

schema_name_characteristic:
  SCHEMA value_specification { $$.v = $2.v }

%%
