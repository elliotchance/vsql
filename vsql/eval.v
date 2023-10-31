// eval.v executes expressions (such as you would find in a WHERE condition).

module vsql

// A ExprOperation executes expressions for each row.
struct ExprOperation {
mut:
	conn    &Connection
	params  map[string]Value
	exprs   []DerivedColumn
	columns []Column
}

fn new_expr_operation(mut conn Connection, params map[string]Value, select_list SelectList, tables map[string]Table) !ExprOperation {
	mut exprs := []DerivedColumn{}
	mut columns := []Column{}

	match select_list {
		AsteriskExpr {
			for _, table in tables {
				columns << table.columns
				for column in table.columns {
					exprs << DerivedColumn{ValueExpression(CommonValueExpression(DatetimePrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(column.name))))), Identifier{
						sub_entity_name: column.name.sub_entity_name
					}}
				}
			}
		}
		QualifiedAsteriskExpr {
			mut table_name := conn.resolve_table_identifier(select_list.table_name, true)!
			table := tables[table_name.id()] or { return sqlstate_42p01('table', table_name.str()) }
			columns = table.columns
			for column in table.columns {
				exprs << DerivedColumn{ValueExpression(BooleanValueExpression{
					term: BooleanTerm{
						factor: BooleanTest{
							expr: BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(column.name)))
						}
					}
				}), Identifier{
					sub_entity_name: column.name.sub_entity_name
				}}
			}
		}
		[]DerivedColumn {
			empty_row := new_empty_table_row(tables)
			for i, column in select_list {
				mut column_name := 'COL${i + 1}'
				if column.as_clause.sub_entity_name != '' {
					column_name = column.as_clause.sub_entity_name
				} else if column.expr is CommonValueExpression {
					if column.expr is DatetimePrimary {
						if column.expr is ValueExpressionPrimary {
							if column.expr is NonparenthesizedValueExpressionPrimary {
								if column.expr is Identifier {
									e := column.expr
									column_name = e.sub_entity_name
								}
							}
						}
					}
				}

				expr := column.expr.resolve_identifiers(conn, tables)!
				col := Identifier{
					sub_entity_name: column_name
				}

				columns << Column{col, expr.eval_type(conn, empty_row, params)!, false}

				exprs << DerivedColumn{expr, col}
			}
		}
	}

	return ExprOperation{conn, params, exprs, columns}
}

fn (o ExprOperation) str() string {
	return 'EXPR (${o.columns()})'
}

fn (o ExprOperation) columns() Columns {
	return o.columns
}

fn (mut o ExprOperation) execute(rows []Row) ![]Row {
	mut new_rows := []Row{}

	for row in rows {
		mut data := map[string]Value{}
		for expr in o.exprs {
			data[expr.as_clause.id()] = expr.expr.eval(mut o.conn, row, o.params)!
		}
		new_rows << new_row(data)
	}

	return new_rows
}

fn eval_row(mut conn Connection, data Row, r RowValueConstructor, params map[string]Value) !Row {
	mut col_number := 1
	mut row := map[string]Value{}
	match r {
		ExplicitRowValueConstructor {
			match r {
				ExplicitRowValueConstructorRow {
					for expr in r.exprs {
						row['COL${col_number}'] = expr.eval(mut conn, data, params)!
						col_number++
					}
				}
				QueryExpression {
					panic('query expressions cannot be used in ROW constructors')
				}
			}
		}
		CommonValueExpression, BooleanValueExpression {
			row['COL${col_number}'] = r.eval(mut conn, data, params)!
		}
	}

	return Row{
		data: row
	}
}

fn time_value(conn &Connection, prec int, include_offset bool) string {
	now, _ := conn.now()

	mut s := now.strftime('%H:%M:%S')

	if prec > 0 {
		microseconds := left_pad(int(now.nanosecond / 1000).str(), '0', 6)
		s += '.' + microseconds.substr(0, prec)
	}

	if include_offset {
		s += time_zone_value(conn)
	}

	return s
}

fn left_pad(s string, c string, len int) string {
	mut new_s := s
	for new_s.len < len {
		new_s = c + new_s
	}

	return new_s
}

fn eval_as_bool(mut conn Connection, data Row, e BooleanValueExpression, params map[string]Value) !bool {
	v := e.eval(mut conn, data, params)!

	if v.typ.typ == .is_boolean {
		return v.bool_value() == .is_true
	}

	return sqlstate_42804('in expression', 'BOOLEAN', v.typ.str())
}

fn cast_approximate(v Value, want SQLType) !Value {
	if v.typ.typ == .is_numeric && v.typ.size == 0 {
		match want {
			.is_double_precision {
				return new_double_precision_value(v.as_f64()!)
			}
			.is_real {
				return new_real_value(f32(v.as_f64()!))
			}
			.is_bigint {
				return new_bigint_value(i64(v.as_f64()!))
			}
			.is_smallint {
				return new_smallint_value(i16(v.as_f64()!))
			}
			.is_integer {
				return new_integer_value(int(v.as_f64()!))
			}
			else {
				// Let it fall through.
			}
		}
	}

	return v
}

fn eval_binary(mut conn Connection, data Row, x Value, op string, y Value, params map[string]Value) !Value {
	mut left := x
	mut right := y

	// There is a special case we need to deal with when using literals against
	// other approximate types.
	//
	// TODO(elliotchance): This won't be needed when we properly implement
	//  ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>
	mut key := '${left.typ.typ} ${op} ${right.typ.typ}'
	if left.typ.typ.is_number() && right.typ.typ.is_number() {
		supertype := most_specific_value(left, right) or {
			return sqlstate_42883('operator does not exist: ${key}')
		}
		left = cast_numeric(mut conn, cast_approximate(left, supertype.typ)!, supertype)!
		right = cast_numeric(mut conn, cast_approximate(right, supertype.typ)!, supertype)!
		key = '${supertype.typ} ${op} ${supertype.typ}'
	}

	if fnc := conn.binary_operators[key] {
		op_fn := fnc as BinaryOperatorFunc
		return op_fn(conn, left, right)
	}

	return sqlstate_42883('operator does not exist: ${key}')
}

// eval_as_nullable_value is a broader version of eval_as_value that also takes
// the known destination type as so allows for untyped NULLs.
//
// TODO(elliotchance): Is this even needed? Can eval_as_value be refactored to
//  work the same way and avoid this extra layer?
fn eval_as_nullable_value(mut conn Connection, typ SQLType, data Row, e ContextuallyTypedRowValueConstructor, params map[string]Value) !Value {
	if e is NullSpecification {
		return new_null_value(typ)
	}

	return e.eval(mut conn, data, params)
}
