%%

// ISO/IEC 9075-2:2023, 19.6, <set schema statement>, Conformance Rules, 1

set_schema_statement:
  SET schema_name_characteristic {
    flag(mut yylex, 'F761')
    $$.v = yy_box(SetSchemaStatement{$2.v as ValueSpecification})
  }
// USE isn't part of the standard (see the V121 feature in the SQL Flagger). The
// name is the value of a SET SCHEMA, as it was written.
| USE identifier {
    flag(mut yylex, 'F761')
    flag(mut yylex, vsql_use)
    $$.v = yy_box(SetSchemaStatement{ValueSpecification(new_character_value(($2.v as IdentifierChain).identifier))})
  }
| USE identifier period identifier {
    flag(mut yylex, 'F761')
    flag(mut yylex, vsql_use)
    $$.v = yy_box(SetSchemaStatement{ValueSpecification(new_character_value(($2.v as IdentifierChain).identifier +
      '.' + ($4.v as IdentifierChain).identifier))})
  }

schema_name_characteristic:
  SCHEMA value_specification { $$.v = $2.v }

%%
