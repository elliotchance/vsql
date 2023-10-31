module vsql

// ISO/IEC 9075-2:2016(E), 6.5, <contextually typed value specification>
//
// # Function
//
// Specify a value whose data type is to be inferred from its context.
//
// # Format
//~
//~ <contextually typed value specification> /* NullSpecification */ ::=
//~     <implicitly typed value specification>
//~
//~ <implicitly typed value specification> /* NullSpecification */ ::=
//~     <null specification>
//~
//~ <null specification> /* NullSpecification */ ::=
//~     NULL   -> null_specification

// NullSpecification (not to be confused with NullPredicate) represents an
// untyped NULL. This exists as an expression (rather than a special value)
// because it's devoid of a type until it's used in an actual expression. Also,
// having it use it's own SQLType creates a lot of branches in the codebase that
// require "this should not be possible" comments and panics.
struct NullSpecification {}

fn (e NullSpecification) pstr(params map[string]Value) string {
	return 'NULL'
}

fn (e NullSpecification) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return error('cannot determine value of untyped NULL')
}

fn (e NullSpecification) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return error('cannot determine type of untyped NULL')
}

fn (e NullSpecification) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return false
}

fn (e NullSpecification) resolve_identifiers(conn &Connection, tables map[string]Table) !NullSpecification {
	return e
}

fn parse_null_specification() !NullSpecification {
	return NullSpecification{}
}
