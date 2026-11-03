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
mut:
	conn &Connection
	plan Plan
}

fn new_join_operation(left_columns Columns, join_type JoinType, right_columns Columns, specification BooleanValueExpression, common_columns []CommonColumn, params map[string]Value, conn &Connection, plan Plan, tables map[string]Table) &JoinOperation {
	return &JoinOperation{left_columns, join_type, right_columns, specification, common_columns, params, tables, conn, plan}
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
fn (mut o JoinOperation) execute(_ []Row) ![]Row {
	left_rows := o.plan.subplans['\$1'].execute([]Row{})!
	right_rows := o.plan.subplans['\$2'].execute([]Row{})!

	mut rows := match o.join_type {
		.inner { o.execute_inner(left_rows, right_rows)! }
		.left { o.execute_left(left_rows, right_rows)! }
		.right { o.execute_right(left_rows, right_rows)! }
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
			row.data[common.column.name.id()] = compiled.run(mut o.conn, row, o.params)!
		}
	}

	return rows
}

fn (mut o JoinOperation) execute_inner(left_rows []Row, right_rows []Row) ![]Row {
	mut new_rows := []Row{}

	for left_row in left_rows {
		for right_row in right_rows {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}
			for k, v in right_row.data {
				row.data[k] = v
			}

			if eval_as_bool(mut o.conn, row, o.specification, o.params, o.tables)! {
				new_rows << row
			}
		}
	}

	return new_rows
}

fn (mut o JoinOperation) execute_left(left_rows []Row, right_rows []Row) ![]Row {
	mut new_rows := []Row{}

	for left_row in left_rows {
		mut matched := false

		for right_row in right_rows {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}

			for k, v in right_row.data {
				row.data[k] = v
			}

			if eval_as_bool(mut o.conn, row, o.specification, o.params, o.tables)! {
				new_rows << row
				matched = true
			}
		}

		if !matched {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}

			for k in o.right_columns {
				row.data[k.name.id()] = new_null_value(k.typ.typ)
			}

			new_rows << row
		}
	}

	return new_rows
}

fn (mut o JoinOperation) execute_right(left_rows []Row, right_rows []Row) ![]Row {
	mut new_rows := []Row{}

	for right_row in right_rows {
		mut matched := false

		for left_row in left_rows {
			mut row := new_row(map[string]Value{})

			for k, v in left_row.data {
				row.data[k] = v
			}

			for k, v in right_row.data {
				row.data[k] = v
			}

			if eval_as_bool(mut o.conn, row, o.specification, o.params, o.tables)! {
				new_rows << row
				matched = true
			}
		}

		if !matched {
			mut row := new_row(map[string]Value{})

			for k in o.left_columns {
				row.data[k.name.id()] = new_null_value(k.typ.typ)
			}

			for k, v in right_row.data {
				row.data[k] = v
			}

			new_rows << row
		}
	}

	return new_rows
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
