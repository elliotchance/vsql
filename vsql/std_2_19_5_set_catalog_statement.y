%%

set_catalog_statement:
  SET catalog_name_characteristic {
    flag(mut yylex, 'F651')
    flag(mut yylex, 'F761')
    $$.v = Stmt(SetCatalogStatement{$2.v as ValueSpecification})
  }

catalog_name_characteristic:
  CATALOG value_specification { $$.v = $2.v as ValueSpecification }

%%
