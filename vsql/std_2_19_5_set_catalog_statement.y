%%

set_catalog_statement:
  SET catalog_name_characteristic {
    $$.v = Stmt(SetCatalogStatement{$2.v as ValueSpecification})
  }

catalog_name_characteristic:
  CATALOG value_specification { $$.v = $2.v as ValueSpecification }

%%
