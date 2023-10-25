// ISO/IEC 9075-2:2016(E), 6.4, <value specification> and <target specification>

module vsql

// Format
//~
//~ <value specification> /* Expr */ ::=
//~     <literal>
//~   | <general value specification>
//~
//~ <unsigned value specification> /* Expr */ ::=
//~     <unsigned literal>              -> value_to_expr
//~   | <general value specification>
//~
//~ <general value specification> /* Expr */ ::=
//~     <host parameter specification>
//~   | CURRENT_CATALOG                  -> current_catalog
//~   | CURRENT_SCHEMA                   -> current_schema
//~
//~ <simple value specification> /* Expr */ ::=
//~     <literal>
//~   | <host parameter name>
//~
//~ <host parameter specification> /* Expr */ ::=
//~     <host parameter name>

fn parse_current_catalog() !Expr {
	return CurrentCatalogExpr{}
}

fn parse_current_schema() !Expr {
	return CurrentSchemaExpr{}
}

fn parse_value_to_expr(v Value) !Expr {
	return v
}
