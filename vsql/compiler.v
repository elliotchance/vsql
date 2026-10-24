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
	// aggregates collects every aggregate function found while compiling an
	// expression (such as both in "MIN(x) * AVG(x)") so that they can be
	// calculated for each group before the expression is evaluated.
	aggregates []AggregateFunction
	// next_value_not_allowed is set to the clause being compiled (such as
	// "WHERE") when it can't contain a NEXT VALUE FOR.
	//
	// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 2
	next_value_not_allowed string
	// grouping_columns is set when compiling the select list of a grouped query.
	// A column reference must then be one of these, unless it's in the argument
	// of an aggregate function (in_aggregate).
	//
	// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Conformance Rules, 3
	grouping_columns ?[]Column
	in_aggregate     bool
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
