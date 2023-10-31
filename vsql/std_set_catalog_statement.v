// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>

module vsql

// Format
//~
//~ <set catalog statement> /* Stmt */ ::=
//~     SET <catalog name characteristic>   -> set_catalog_stmt
//~
//~ <catalog name characteristic> /* ValueSpecification */ ::=
//~     CATALOG <value specification>   -> catalog_name_characteristic

struct SetCatalogStatement {
	catalog_name ValueSpecification
}

fn (e SetCatalogStatement) pstr(params map[string]Value) string {
	return 'SET CATALOG ${e.catalog_name.pstr(params)}'
}

fn parse_set_catalog_stmt(catalog_name ValueSpecification) !Stmt {
	return SetCatalogStatement{catalog_name}
}

fn parse_catalog_name_characteristic(v ValueSpecification) !ValueSpecification {
	return v
}
