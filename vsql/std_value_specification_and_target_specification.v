module vsql

// ISO/IEC 9075-2:2016(E), 6.4, <value specification> and <target specification>
//
// # Function
//
// Specify one or more values, host parameters, SQL parameters, dynamic
// parameters, or host variables.
//
// # Format
//~
//~ <value specification> /* ValueSpecification */ ::=
//~     <literal>                       -> ValueSpecification
//~   | <general value specification>   -> ValueSpecification
//~
//~ <unsigned value specification> /* ValueSpecification */ ::=
//~     <unsigned literal>              -> ValueSpecification
//~   | <general value specification>   -> ValueSpecification
//~
//~ <general value specification> /* GeneralValueSpecification */ ::=
//~     <host parameter specification>
//~   | CURRENT_CATALOG                  -> current_catalog
//~   | CURRENT_SCHEMA                   -> current_schema
//~
//~ <simple value specification> /* ValueSpecification */ ::=
//~     <literal>               -> ValueSpecification
//~   | <host parameter name>   -> ValueSpecification
//~
//~ <host parameter specification> /* GeneralValueSpecification */ ::=
//~     <host parameter name>

type ValueSpecification = GeneralValueSpecification | Value

fn (e ValueSpecification) pstr(params map[string]Value) string {
	return match e {
		Value, GeneralValueSpecification { e.pstr(params) }
	}
}

fn (e ValueSpecification) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		Value, GeneralValueSpecification { e.eval_type(conn, data, params)! }
	}
}

fn (e ValueSpecification) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		Value, GeneralValueSpecification { e.eval(mut conn, data, params)! }
	}
}

fn (e ValueSpecification) resolve_identifiers(conn &Connection, tables map[string]Table) !ValueSpecification {
	return e
}

type GeneralValueSpecification = CurrentCatalog | CurrentSchema | HostParameterName

// CURRENT_CATALOG
struct CurrentCatalog {
}

// CURRENT_SCHEMA
struct CurrentSchema {
}

fn (e GeneralValueSpecification) pstr(params map[string]Value) string {
	return match e {
		HostParameterName { e.pstr(params) }
		CurrentCatalog { 'CURRENT_CATALOG' }
		CurrentSchema { 'CURRENT_SCHEMA' }
	}
}

fn (e GeneralValueSpecification) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		HostParameterName { e.eval_type(conn, data, params)! }
		CurrentCatalog, CurrentSchema { new_type('CHARACTER VARYING', 0, 0) }
	}
}

fn (e GeneralValueSpecification) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		HostParameterName { e.eval(mut conn, data, params)! }
		CurrentCatalog { new_varchar_value(conn.current_catalog) }
		CurrentSchema { new_varchar_value(conn.current_schema) }
	}
}

fn parse_current_catalog() !GeneralValueSpecification {
	return CurrentCatalog{}
}

fn parse_current_schema() !GeneralValueSpecification {
	return CurrentSchema{}
}
