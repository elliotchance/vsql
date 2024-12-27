module vsql

// ISO/IEC 9075-2:2016(E), 6.5, <contextually typed value specification>
//
// Specify a value whose data type is to be inferred from its context.

// NullSpecification (not to be confused with NullPredicate) represents an
// untyped NULL. This exists as an expression (rather than a special value)
// because it's devoid of a type until it's used in an actual expression. Also,
// having it use it's own SQLType creates a lot of branches in the codebase that
// require "this should not be possible" comments and panics.
struct NullSpecification {}

fn (e NullSpecification) pstr(params map[string]Value) string {
	return 'NULL'
}

fn (e NullSpecification) compile(mut c Compiler) !CompileResult {
	if null_type := c.null_type {
		return CompileResult{
			run:          fn [null_type] (mut conn Connection, data Row, params map[string]Value) !Value {
				return new_null_value(null_type.typ)
			}
			typ:          null_type
			contains_agg: false
		}
	}

	return error('cannot determine value of untyped NULL')
}

fn (e NullSpecification) resolve_identifiers(conn &Connection, tables map[string]Table) !NullSpecification {
	return e
}
