// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>

module vsql

// Format
//~
//~ <set catalog statement> /* Stmt */ ::=
//~     SET <catalog name characteristic>   -> set_catalog_stmt
//~
//~ <catalog name characteristic> /* Expr */ ::=
//~     CATALOG <value specification>   -> expr

fn parse_set_catalog_stmt(catalog_name Expr) !Stmt {
	return SetCatalogStmt{catalog_name}
}
