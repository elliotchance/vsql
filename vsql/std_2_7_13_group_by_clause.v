module vsql

// ISO/IEC 9075-2:2016(E), 7.13, <group by clause>
//
// Specify a grouped table derived by the application of the <group by clause>
// to the result of the previously specified clause.

struct GroupOperation {
	// select_exprs contains the original SELECT expressions, both the aggregate
	// and non-aggrgate expressions, such as "a, count(*)".
	//
	// It only works with []DerivedColumn because other forms of SelectList are
	// impossible to use with GROUP BY.
	select_exprs []DerivedColumn
	// group_exprs contains the expressions for the GROUP BY itself, such as
	// "a".
	//
	// The SQL standard doesn't actually allow anything other than a identifer
	// to be used in GROUP BY expressions, but well keep them as []Identifier
	// because it's easier.
	group_exprs []Identifier
	// having is also used to find aggregate functions that need to be calculated
	// for each group, such as "COUNT(*)" in "HAVING COUNT(*) > 1".
	having ?BooleanValueExpression

	params  map[string]Value
	columns Columns
	tables  map[string]Table
mut:
	conn &Connection
}

fn new_group_operation(select_exprs []DerivedColumn, group_exprs []Identifier, having ?BooleanValueExpression, params map[string]Value, mut conn Connection, tables map[string]Table) !&GroupOperation {
	mut columns := []Column{}

	for expr in group_exprs {
		columns << group_column(expr, tables)!
	}

	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}
	for expr in select_exprs {
		compiled_expr := expr.expr.compile(mut c)!
		if compiled_expr.contains_agg {
			columns << Column{Identifier{
				custom_id:  expr.expr.pstr(params)
				custom_typ: compiled_expr.typ
			}, compiled_expr.typ, false, none, none}
		}
	}

	return &GroupOperation{select_exprs, group_exprs, having, params, columns, tables, conn}
}

// group_column finds the column for a GROUP BY expression in the tables of the
// FROM clause. A qualified name (such as "b.x") must match the table name.
fn group_column(expr Identifier, tables map[string]Table) !Column {
	// An unqualified column name must only be in one of the tables (6.6 Syntax
	// Rule 8c).
	if expr.entity_name == '' {
		mut tables_with_column := map[string]bool{}
		for _, table in tables {
			if _ := table.column(expr.sub_entity_name) {
				tables_with_column[table.name.id()] = true
			}
		}
		if tables_with_column.len > 1 {
			return sqlstate_42702(expr.sub_entity_name)
		}
	}

	for _, table in tables {
		if expr.entity_name != '' && expr.entity_name != table.name.entity_name
			&& expr.entity_name != table.name.sub_entity_name {
			continue
		}

		if column := table.column(expr.sub_entity_name) {
			return column
		}
	}

	return sqlstate_42703(expr.sub_entity_name) // column does not exist
}

fn (o &GroupOperation) str() string {
	return 'GROUP BY (${o.columns()})'
}

fn (o &GroupOperation) columns() Columns {
	return o.columns
}

fn (mut o GroupOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
		tables: o.tables
	}

	// Create the grouped sets.
	mut sets := [][]Row{}

	// Without a GROUP BY the whole table is a single group, even if it has no
	// rows. For example, "SELECT COUNT(*) FROM t" must always return one row.
	if rows.len > 0 || o.group_exprs.len == 0 {
		sets << []Row{}
	}

	for row in rows {
		if sets[sets.len - 1].len == 0 {
			sets[sets.len - 1] << row
			continue
		}

		mut equal := true
		for expr in o.group_exprs {
			left := expr.compile(mut c)!.run(mut o.conn,
				sets[sets.len - 1][sets[sets.len - 1].len - 1], o.params)!
			right := expr.compile(mut c)!.run(mut o.conn, row, o.params)!

			if left.is_null && right.is_null {
				continue
			}

			cmp := compare(o.conn, left, right)!
			if cmp != .is_equal {
				equal = false
				break
			}
		}

		if equal {
			sets[sets.len - 1] << row
		} else {
			sets << [row]
		}
	}

	// Each set will produce one row. An empty set (only possible without a GROUP
	// BY) has no row to store the aggregate results in.
	//
	// The data is cloned because the aggregate results are added to it below.
	// Otherwise the map would be shared with set[0], and growing it can lose
	// the values of set[0] before the next aggregate function reads them.
	mut final_rows := []Row{}
	for set in sets {
		final_rows << if set.len > 0 {
			new_row(set[0].data.clone())
		} else {
			new_row(map[string]Value{})
		}
	}

	// Perform the aggregations functions. An expression may contain several
	// aggregate functions (such as "MIN(x) * AVG(x)"), each result is stored in
	// the row so that it can be used when the expression is evaluated. The
	// HAVING may also use aggregate functions that are not in the select list.
	mut agg_c := Compiler{
		conn:   o.conn
		params: o.params
		tables: o.tables
	}
	for expr in o.select_exprs {
		expr.expr.compile(mut agg_c)!
	}
	if having := o.having {
		having.compile(mut agg_c)!
	}

	mut null_eliminated := false
	for aggregate in agg_c.aggregates {
		key := aggregate.pstr(o.params)
		for i, set in sets {
			match aggregate {
				AggregateFunctionCount {
					final_rows[i].data[key] = new_integer_value(set.len)
				}
				RoutineInvocation {
					arg := aggregate.args[0].compile(mut c)!
					mut values := []Value{}
					for row in set {
						value := arg.run(mut o.conn, row, o.params)!
						if value.is_null {
							null_eliminated = true
						}
						values << value
					}

					if aggregate.distinct {
						values = distinct_values(o.conn, values)!
					}

					final_rows[i].data[key] = eval_set_function(mut o.conn, aggregate.function_name,
						values, arg.typ)!
				}
			}
		}
	}

	// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7a
	if null_eliminated {
		o.conn.add_warning(sqlstate_01003())
	}

	return final_rows
}
