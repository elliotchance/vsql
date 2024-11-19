module vsql

struct Compiler {
	tables map[string]Table
	params map[string]Value @[required]
mut:
	conn &Connection @[required]
	// context is used to describe the indetifier environment. For example, in an
	// UPDATE statement we know the table we're operating on and so any
	// identifiers have to be reoslved against that instead of just searching all
	// tables.
	context Identifier
	// Untyped NULLs should be treated as this type.
	null_type ?Type
}

type CompiledFn = fn (mut conn Connection, data Row, params map[string]Value) !Value

struct CompileResult {
	run          CompiledFn @[required]
	typ          Type       @[required]
	contains_agg bool       @[required]
}

fn (c CompileResult) with_agg(contains_agg bool) CompileResult {
	return CompileResult{
		run:          c.run
		typ:          c.typ
		contains_agg: contains_agg
	}
}
