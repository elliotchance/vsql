module vsql

// The concept is described by ISO/IEC 9075-1:2003(E), 4.7.2, Determinism and
// constraints.

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
	// aggregated_columns collects the column references in the argument of the
	// aggregate function being compiled, to find the query that it's an
	// aggregate of (see aggregation_scope).
	aggregated_columns []AggregatedColumn
	// aggregation_query is set when compiling a VALUES, which isn't a query
	// specification, see values_aggregation_query.
	aggregation_query ?int
	// distinct is set when compiling the select list of a "SELECT DISTINCT".
	distinct bool
	// distinct_columns is set when compiling an ORDER BY of a "SELECT DISTINCT".
	// A column reference must then be one of these columns of the select list,
	// unless the whole sort key is also in the select list.
	//
	// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 28.d
	distinct_columns ?[]Column
	// result_columns is set when compiling an ORDER BY, see set_result_columns.
	result_columns map[string][]ValueExpression
	// uses_next_value is set when a NEXT VALUE FOR is compiled.
	uses_next_value bool
	// next_value_sort_keys are the select list items that a sort key refers to by
	// name, and that use a NEXT VALUE FOR, see SequenceValuesOperation.
	next_value_sort_keys []ValueExpression
	// restricted is set to what's being compiled (such as "a CHECK constraint")
	// when it must be deterministic (see check_deterministic) and can't contain a
	// subquery or a parameter. A CHECK on a column can only use that column,
	// check_column. A generation expression can't use a generated column, and
	// generation_column is the column it's for. The columns that a CHECK or a
	// generation expression uses are collected in check_columns (see
	// CheckConstraintDefinition.columns). Since a parameter can't be used, it
	// also can't be in the <table contents source> of a <table definition>.
	//
	// ISO/IEC 9075-2:2016(E), 11.3, <table definition>, Syntax Rules, 4
	restricted string
	// retrospective is set while compiling the search condition of a CHECK, until
	// it gets to something that isn't a <boolean value expression> that can be
	// retrospectively deterministic (see compile_retrospective).
	retrospective     bool
	check_column      string
	generation_column string
	check_columns     map[string]bool
	// stored_definition is set when compiling a CHECK or generation expression of
	// a table that's already defined. Its names were checked when it was defined,
	// so a qualifier that doesn't have a schema or catalog must still be the table,
	// whatever the current schema and catalog are now.
	//
	// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Syntax Rules, 4
	stored_definition bool
}

// An AggregatedColumn is a column reference in the argument of an aggregate
// function. scope is the subquery scope of the query that the column is from
// (see Identifier.compile_outer), or -1 for a column of this query. ungrouped
// is set for an outer reference that isn't a grouping column of its (grouped)
// query.
struct AggregatedColumn {
	scope     int
	name      string
	ungrouped bool
}

// aggregation_scope is the subquery scope of the query that the aggregate
// function being compiled is an aggregate of, or -1 if it's of this query. It's
// the innermost query of its column references, so only an aggregate function
// of outer references is an aggregate of another query, such as the MAX in
// "SELECT (SELECT MAX(t1.x) FROM t2) FROM t1". Any other outer reference must
// still be a grouping column of its query. An aggregate function without any
// column references is of this query, unless it's in a VALUES.
//
// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 6 and 8
fn (c Compiler) aggregation_scope() !int {
	if c.aggregated_columns.len == 0 {
		return c.aggregation_query or { -1 }
	}

	mut scope := -1
	if c.aggregated_columns.all(it.scope >= 0) {
		for column in c.aggregated_columns {
			if column.scope > scope {
				scope = column.scope
			}
		}
	}

	for column in c.aggregated_columns {
		if column.ungrouped && column.scope != scope {
			return sqlstate_42803(column.name)
		}
	}

	return scope
}

// set_grouping_columns is called before compiling an ORDER BY. If the query
// specification is a grouped table, a column of a sort key must be one of its
// grouping columns. It's still grouped without a GROUP BY when it has a HAVING or
// an aggregate function, and it doesn't have any grouping columns then.
fn (mut c Compiler) set_grouping_columns(body SimpleTable) ! {
	if body !is QuerySpecification {
		return
	}

	query := body as QuerySpecification
	mut select_list := Compiler{
		conn:   c.conn
		params: c.params
		tables: c.tables
	}
	mut is_grouped := query.table_expression.group_clause.len > 0
		|| query.table_expression.having_clause != none
	if query.exprs is []SelectSublist {
		for item in query.exprs {
			if item is DerivedColumn && item.expr.compile(mut select_list)!.contains_agg {
				is_grouped = true
			}
		}
	}
	if !is_grouped {
		return
	}

	mut columns := []Column{}
	for column in query.table_expression.group_clause {
		columns << group_column(column, c.tables)!
	}
	c.grouping_columns = columns
}

// check_deterministic returns an error if the expression (described by what)
// is possibly non-deterministic and it's in a CHECK constraint or a generation
// expression. Otherwise, the constraint could be satisfied when a row is
// written but not later, or a generated column could have a different value if
// the row was written again.
//
// A CHECK constraint only has to be retrospectively deterministic, so a
// comparison with CURRENT_DATE can be allowed (see compile_retrospective).
//
// ISO/IEC 9075-2:2016(E), 11.9, <check constraint definition>, Syntax Rules, 5
// ISO/IEC 9075-2:2016(E), 11.4, <column definition>, Syntax Rules, 10.d
// ISO/IEC 9075-2:2016(E), 6.28, <value expression>, Syntax Rules, 7
// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>, Syntax Rules, 5
fn (c Compiler) check_deterministic(what string) ! {
	if c.restricted != '' {
		return sqlstate_42601('${what} cannot be used in ${c.restricted}')
	}
}

// compile_retrospective compiles the comparand Y of a retrospectively
// deterministic comparison, such as "X < Y". Once it's true it stays true, since
// time only moves forward. There are no intervals (F052), so it can't be Y + Z
// or Y - Z. If it isn't exactly one of the functions, it's compiled the same as
// any other comparand.
//
// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>, Syntax Rules, 5.c.ii
fn (mut c Compiler) compile_retrospective(e RowValueConstructorPredicand) !CompileResult {
	y := e.pstr(c.params)
	if y != 'CURRENT_DATE' && !(y.len == 'CURRENT_TIMESTAMP(0)'.len
		&& y.starts_with('CURRENT_TIMESTAMP(')) && !(y.len == 'LOCALTIMESTAMP(0)'.len
		&& y.starts_with('LOCALTIMESTAMP(')) {
		return e.compile(mut c)!
	}

	restricted := c.restricted
	c.restricted = ''
	defer {
		c.restricted = restricted
	}

	return e.compile(mut c)!
}

// check_time_zone_comparison returns an error if a datetime with a time zone is
// compared with one without a time zone in a CHECK constraint. The one without
// a time zone is in the time zone of the session, so the result depends on the
// session.
//
// ISO/IEC 9075-2:2016(E), 6.28, <value expression>, Syntax Rules, 7.g
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
