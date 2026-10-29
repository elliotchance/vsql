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

type GeneralValueSpecification = CurrentCatalog | CurrentSchema | DynamicParameterSpecification

// CURRENT_CATALOG
struct CurrentCatalog {
}

// CURRENT_SCHEMA
struct CurrentSchema {
}

// DynamicParameterSpecification is a "?". It's named by its position, such as
// "?1" for the first "?" in the statement (see tokenize).
struct DynamicParameterSpecification {
	name string
}

fn (e DynamicParameterSpecification) pstr(params map[string]Value) string {
	return params[e.name].pstr(params)
}

fn (e DynamicParameterSpecification) compile(mut c Compiler) !CompileResult {
	// ISO/IEC 9075-2:2016(E), 11.9, <check constraint definition>, Syntax Rule 1
	// ISO/IEC 9075-2:2016(E), 11.4, <column definition>, Syntax Rule 1
	if c.restricted != '' {
		return sqlstate_42601('parameter ${e.name} cannot be used in ${c.restricted}')
	}

	p := c.params[e.name] or { return sqlstate_42p02(e.name) }

	return CompileResult{
		run:          fn [p] (mut conn Connection, data Row, params map[string]Value) !Value {
			return p
		}
		typ:          p.typ
		contains_agg: false
	}
}

fn (e GeneralValueSpecification) pstr(params map[string]Value) string {
	return match e {
		DynamicParameterSpecification { e.pstr(params) }
		CurrentCatalog { 'CURRENT_CATALOG' }
		CurrentSchema { 'CURRENT_SCHEMA' }
	}
}

fn (e GeneralValueSpecification) compile(mut c Compiler) !CompileResult {
	match e {
		DynamicParameterSpecification {
			return e.compile(mut c)!
		}
		CurrentCatalog {
			c.check_deterministic('CURRENT_CATALOG')!

			return CompileResult{
				run:          fn (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_varchar_value(conn.current_catalog)
				}
				typ:          new_type('CHARACTER VARYING', 0, 0)
				contains_agg: false
			}
		}
		CurrentSchema {
			c.check_deterministic('CURRENT_SCHEMA')!

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
