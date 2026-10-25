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
	// default_value is the default of the column that a DEFAULT is assigned to.
	// A column without a default (or when it's not set) has a default of NULL.
	default_value ?DefaultOption
	// identity is the table when a DEFAULT is assigned to its identity column,
	// so that it's the next value of the sequence of the column instead.
	identity ?Table
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
	// distinct is set when compiling the select list of a "SELECT DISTINCT".
	distinct bool
	// distinct_columns is set when compiling an ORDER BY of a "SELECT DISTINCT".
	// A column reference must then be one of these columns of the select list,
	// unless the whole sort key is also in the select list.
	//
	// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 28d
	distinct_columns ?[]Column
	// restricted is set to what's being compiled (such as "a CHECK constraint")
	// when it must be deterministic (see check_deterministic) and can't contain a
	// subquery or a parameter. A CHECK on a column can only use that column,
	// check_column. A generation expression can't use a generated column, and
	// generation_column is the column it's for.
	restricted        string
	check_column      string
	generation_column string
}

// check_deterministic returns an error if the expression (described by what)
// is possibly non-deterministic and it's in a CHECK constraint or a generation
// expression. Otherwise, the constraint could be satisfied when a row is
// written but not later, or a generated column could have a different value if
// the row was written again.
//
// ISO/IEC 9075-2:2016(E), 11.9, <check constraint definition>, Syntax Rule 5
// ISO/IEC 9075-2:2016(E), 11.4, <column definition>, Syntax Rule 10d
// ISO/IEC 9075-2:2016(E), 6.28, <value expression>, Syntax Rule 7
fn (c Compiler) check_deterministic(what string) ! {
	if c.restricted != '' {
		return sqlstate_42601('${what} cannot be used in ${c.restricted}')
	}
}

// check_time_zone_comparison returns an error if a datetime with a time zone is
// compared with one without a time zone in a CHECK constraint. The one without
// a time zone is in the time zone of the session, so the result depends on the
// session.
//
// ISO/IEC 9075-2:2016(E), 6.28, <value expression>, Syntax Rule 7g
fn (c Compiler) check_time_zone_comparison(left Type, right Type) ! {
	if left.typ.is_datetime() && right.typ.is_datetime()
		&& left.has_time_zone() != right.has_time_zone() {
		c.check_deterministic('comparing ${left} with ${right}')!
	}
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
