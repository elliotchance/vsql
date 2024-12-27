module vsql

// ISO/IEC 9075-2:2016(E), 6.4, <value specification> and <target specification>
//
// Specify one or more values, host parameters, SQL parameters, dynamic
// parameters, or host variables.

type ValueSpecification = GeneralValueSpecification | Value

fn (e ValueSpecification) pstr(params map[string]Value) string {
	return match e {
		Value, GeneralValueSpecification { e.pstr(params) }
	}
}

fn (e ValueSpecification) compile(mut c Compiler) !CompileResult {
	match e {
		Value, GeneralValueSpecification {
			return e.compile(mut c)!
		}
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

fn (e GeneralValueSpecification) compile(mut c Compiler) !CompileResult {
	match e {
		HostParameterName {
			return e.compile(mut c)!
		}
		CurrentCatalog {
			return CompileResult{
				run:          fn (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_varchar_value(conn.current_catalog)
				}
				typ:          new_type('CHARACTER VARYING', 0, 0)
				contains_agg: false
			}
		}
		CurrentSchema {
			return CompileResult{
				run:          fn (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_varchar_value(conn.current_schema)
				}
				typ:          new_type('CHARACTER VARYING', 0, 0)
				contains_agg: false
			}
		}
	}
}
