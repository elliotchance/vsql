// ISO/IEC 9075-2:2016(E), 6.4, <value specification> and <target specification>

module vsql

// Format
//~
//~ <value specification> /* Expr */ ::=
//~     <literal>
//~   | <general value specification>   -> value_specification_2
//~
//~ <unsigned value specification> /* UnsignedValueSpecification */ ::=
//~     <unsigned literal>              -> unsigned_value_specification_1
//~   | <general value specification>   -> unsigned_value_specification_2
//~
//~ <general value specification> /* GeneralValueSpecification */ ::=
//~     <host parameter specification>
//~   | CURRENT_CATALOG                  -> current_catalog
//~   | CURRENT_SCHEMA                   -> current_schema
//~
//~ <simple value specification> /* Expr */ ::=
//~     <literal>
//~   | <host parameter name>   -> simple_value_specification_2
//~
//~ <host parameter specification> /* GeneralValueSpecification */ ::=
//~     <host parameter name>

type UnsignedValueSpecification = GeneralValueSpecification | Value

fn (e UnsignedValueSpecification) pstr(params map[string]Value) string {
	return match e {
		Value, GeneralValueSpecification { e.pstr(params) }
	}
}

fn (e UnsignedValueSpecification) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		Value { eval_as_type(conn, data, e, params)! }
		GeneralValueSpecification { e.eval_type(conn, data, params)! }
	}
}

fn (e UnsignedValueSpecification) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		Value { eval_as_value(mut conn, data, e, params)! }
		GeneralValueSpecification { e.eval(mut conn, data, params)! }
	}
}

fn (e UnsignedValueSpecification) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return false
}

fn (e UnsignedValueSpecification) resolve_identifiers(conn &Connection, tables map[string]Table) !Expr {
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

fn parse_unsigned_value_specification_1(v Value) !UnsignedValueSpecification {
	return v
}

fn parse_unsigned_value_specification_2(v GeneralValueSpecification) !UnsignedValueSpecification {
	return v
}

fn parse_value_specification_2(e GeneralValueSpecification) !Expr {
	return UnsignedValueSpecification(e)
}

fn parse_simple_value_specification_2(e GeneralValueSpecification) !Expr {
	return UnsignedValueSpecification(e)
}
