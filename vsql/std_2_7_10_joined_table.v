module vsql

// ISO/IEC 9075-2:2016(E), 7.10, <joined table>
//
// Specify a table derived from a Cartesian product, inner join, or outer join.

struct JoinOperation {
	left_columns  Columns
	join_type     JoinType
	right_columns Columns
	specification BooleanValueExpression
	// common_columns are the columns of a named columns join ("USING").
	common_columns []CommonColumn
	params         map[string]Value
	tables         map[string]Table
	// names are the names of the columns of the rows that lookup reads, when
	// the table has a correlation name (see JoinLookup).
	names map[string]string
mut:
	conn &Connection
	plan Plan
	// lookup reads the rows of the inner side that can match a row of the
	// outer side, when the inner side is a table with an index (or PRIMARY KEY)
	// that the join condition can use.
	lookup ?&KeyOperation
}

fn new_join_operation(left_columns Columns, join_type JoinType, right_columns Columns, specification BooleanValueExpression, common_columns []CommonColumn, params map[string]Value, conn &Connection, plan Plan, tables map[string]Table, lookup ?JoinLookup) &JoinOperation {
	mut names := map[string]string{}
	mut operation := ?&KeyOperation(none)
	if l := lookup {
		if l.table.name.id() != l.base_table.name.id() {
			for i, column in l.base_table.columns {
				names[column.name.id()] = l.table.columns[i].name.id()
			}
		}
		operation = l.operation
	}

	return &JoinOperation{left_columns, join_type, right_columns, specification, common_columns, params, tables, names, conn, plan, operation}
}

// A JoinLookup is how the rows of the inner side of a join (the right side, or
// the left side of a RIGHT join) are found for each row of the outer side, with
// the PRIMARY KEY or an index of a table (base_table). The table is how the
// query names it, which is different with a correlation name, such as
// "t AS x (a, b)".
struct JoinLookup {
	base_table Table
	table      Table
	operation  &KeyOperation
}

fn (o &JoinOperation) str() string {
	return '${o.join_type} JOIN ON ${o.specification.pstr(map[string]Value{})} (${o.columns()})'
}

// columns are the common columns (if any), then the other columns of each side.
// A column of the side that's not preserved by an outer join can be NULL. A NOT
// NULL column of the preserved side still can't be, which is an
// implementation-defined rule (without T101, an outer join is otherwise only ever
// possibly nullable).
//
// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 8, 10.i, 14 and 15
fn (o &JoinOperation) columns() Columns {
	mut hidden := map[string]bool{}
	mut columns := []Column{}
	for common in o.common_columns {
		columns << common.column
		hidden[common.left.name.id()] = true
		hidden[common.right.name.id()] = true
	}

	left_columns := if o.join_type == .right {
		possibly_nullable_columns(o.left_columns)
	} else {
		o.left_columns
	}
	right_columns := if o.join_type == .left {
		possibly_nullable_columns(o.right_columns)
	} else {
		o.right_columns
	}
	for column in left_columns {
		if column.name.id() !in hidden {
			columns << column
		}
	}
	for column in right_columns {
		if column.name.id() !in hidden {
			columns << column
		}
	}

	return columns
}

// possibly_nullable_columns are the same columns, without their NOT NULL.
fn possibly_nullable_columns(columns Columns) Columns {
	mut nullable := []Column{}
	for column in columns {
		nullable << Column{
			...column
			not_null: false
		}
	}

	return nullable
}

// execute joins the rows of both sides. A LEFT (or RIGHT) join also has each
// row of the left (or right) side that didn't match, with NULLs for the other
// side.
//
// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, General Rules, 3-5
//
// The rows are in the order of the outer side (the left side, or the right side
// of a RIGHT join), then the inner side. Each row of the outer side is compared
// with every row of the inner side, or only the rows that lookup finds (if
// any). The whole join condition is still applied to them.
fn (mut o JoinOperation) execute(_ []Row) ![]Row {
	outer, inner := if o.join_type == .right { '\$2', '\$1' } else { '\$1', '\$2' }
	inner_columns := if o.join_type == .right { o.left_columns } else { o.right_columns }
	mut outer_plan := o.plan.subplans[outer] or { Plan{} }
	outer_rows := outer_plan.execute([]Row{})!
	mut all_inner_rows := []Row{}
	if o.lookup == none {
		mut inner_plan := o.plan.subplans[inner] or { Plan{} }
		all_inner_rows = inner_plan.execute([]Row{})!
	}

	mut rows := []Row{}
	mut condition := []CompileResult{cap: 1}
	for outer_row in outer_rows {
		inner_rows := o.inner_rows(outer_row, all_inner_rows)!
		mut matched := false
		for inner_row in inner_rows {
			mut row := new_row(map[string]Value{})
			row.data = row.data.merged(outer_row.data)
			row.data = row.data.merged(inner_row.data)

			if eval_as_bool(mut o.conn, row, o.specification, o.params, o.tables, mut condition)! {
				rows << row
				matched = true
			}
		}

		if !matched && o.join_type != .inner {
			mut row := new_row(map[string]Value{})
			row.data = row.data.merged(outer_row.data)
			for k in inner_columns {
				row.data.set(k.name.id(), new_null_value(k.typ.typ))
			}
			rows << row
		}
	}

	// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, General Rules, 6.a
	mut c := Compiler{
		conn:   o.conn
		params: o.params
		tables: o.tables
	}
	for common in o.common_columns {
		compiled := common.value().compile(mut c)!
		for mut row in rows {
			row.data.set(common.column.name.id(), compiled.run(mut o.conn, row, o.params)!)
		}
	}

	return rows
}

// inner_rows are the rows of the inner side that might match outer_row, which
// is all of them without a lookup.
fn (mut o JoinOperation) inner_rows(outer_row Row, all_inner_rows []Row) ![]Row {
	mut lookup := o.lookup or { return all_inner_rows }
	mut rows := lookup.read(outer_row)!
	if o.names.len == 0 {
		return rows
	}

	for mut row in rows {
		row.data = RowData{
			keys:   row.data.keys.map(o.names[it] or { it })
			values: row.data.values
		}
	}

	return rows
}

// A CommonColumn is a column of the result of a named columns join, the
// coalesced pair of the columns with that name on each side.
struct CommonColumn {
	column Column
	left   Column
	right  Column
}

fn (c CommonColumn) value() ValueExpression {
	return ValueExpression(CommonValueExpression(DatetimePrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(CaseExpression(CaseExpressionCoalesce{[
		column_derived_column(c.left).expr,
		column_derived_column(c.right).expr,
	]}))))))
}

fn (c CommonColumn) equality() BooleanTest {
	return new_boolean_test(BooleanPrimary(Predicate(ComparisonPredicate{RowValueConstructorPredicand(BooleanPredicand(NonparenthesizedValueExpressionPrimary(c.left.name))), ComparisonOperator.equal, RowValueConstructorPredicand(BooleanPredicand(NonparenthesizedValueExpressionPrimary(c.right.name)))})), false, none, false)
}

// new_common_columns finds the columns of a named columns join. They're always
// in the order of the left side, not the order of the list. A column is known
// not null when the join can't produce a NULL for it: both sides are equal (so
// not NULL) in a matched row, so that only depends on the side that's kept for a
// row that isn't matched.
//
// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 10.c, 10.e, 10.f and 15.c
fn new_common_columns(names []Identifier, join_type JoinType, left_columns Columns, right_columns Columns, range_variable string) ![]CommonColumn {
	mut seen := map[string]bool{}
	for name in names {
		if name.sub_entity_name in seen {
			return sqlstate_42601('column ${name.sub_entity_name} is specified more than once')
		}
		seen[name.sub_entity_name] = true
		join_column(left_columns, name.sub_entity_name)!
		join_column(right_columns, name.sub_entity_name)!
	}

	mut common_columns := []CommonColumn{}
	for left in left_columns {
		name := left.name.sub_entity_name
		if name !in seen {
			continue
		}

		right := join_column(right_columns, name)!
		typ := combine_types(left.typ, right.typ) or {
			return sqlstate_42804('in USING column ${name}', left.typ.str(), right.typ.str())
		}
		common_columns << CommonColumn{
			column: Column{
				name:     Identifier{
					entity_name:     range_variable
					sub_entity_name: name
				}
				typ:      typ
				not_null: match join_type {
					.inner { true }
					.left { left.not_null }
					.right { right.not_null }
				}
			}
			left:   left
			right:  right
		}
	}

	return common_columns
}

// join_column is the only column with the name on one side of a named columns
// join.
//
// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 10.c
fn join_column(columns Columns, name string) !Column {
	matching := columns.filter(it.name.sub_entity_name == name)
	if matching.len > 1 {
		return sqlstate_42702(name)
	}
	if matching.len == 0 {
		return sqlstate_42703(name)
	}

	return matching[0]
}

// join_equalities is the join condition of a named columns join.
//
// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, General Rules, 1.c
fn join_equalities(common_columns []CommonColumn) BooleanValueExpression {
	mut term := BooleanTerm{
		factor: common_columns[0].equality()
	}
	for common in common_columns[1..] {
		term = new_boolean_and(term, common.equality())
	}

	return BooleanValueExpression{
		term: term
	}
}

fn new_boolean_and(term BooleanTerm, factor BooleanTest) BooleanTerm {
	return BooleanTerm{&term, factor}
}
