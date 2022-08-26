// expr.v contains functions for examining expressions.

module vsql

// expr_is_agg returns true if the expression is or contains an aggregate
// function. That means that the value must be evaluated by the GROUP BY
// (GroupOperation)
fn expr_is_agg(conn &Connection, e Expr, row Row, params map[string]Value) !bool {
	match e {
		BinaryExpr {
			if expr_is_agg(conn, e.left, row, params)! || expr_is_agg(conn, e.right, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		BetweenExpr {
			if expr_is_agg(conn, e.left, row, params)! || expr_is_agg(conn, e.right, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		CallExpr {
			mut arg_types := []Type{}
			for arg in e.args {
				arg_types << eval_as_type(conn, row, arg, params)!
			}

			func := conn.find_function(e.function_name, arg_types)!

			if func.is_agg {
				return true
			}

			for arg in e.args {
				if expr_is_agg(conn, arg, row, params)! {
					return nested_agg_unsupported(e)
				}
			}
		}
		CountAllExpr {
			return true
		}
		Identifier, Parameter, Value, NoExpr, RowExpr, QualifiedAsteriskExpr, QueryExpression,
		CurrentDateExpr, CurrentTimeExpr, CurrentTimestampExpr, LocalTimeExpr, LocalTimestampExpr,
		UntypedNullExpr {
			return false
		}
		LikeExpr {
			if expr_is_agg(conn, e.left, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		NullExpr {
			if expr_is_agg(conn, e.expr, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		CoalesceExpr {
			for expr in e.exprs {
				if expr_is_agg(conn, expr, row, params)! {
					return nested_agg_unsupported(expr)
				}
			}
		}
		NullIfExpr {
			if expr_is_agg(conn, e.a, row, params)! || expr_is_agg(conn, e.b, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		TruthExpr {
			if expr_is_agg(conn, e.expr, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		SimilarExpr {
			if expr_is_agg(conn, e.left, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		SubstringExpr {
			if expr_is_agg(conn, e.value, row, params)! || expr_is_agg(conn, e.from, row, params)!
				|| expr_is_agg(conn, e.@for, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		UnaryExpr {
			if expr_is_agg(conn, e.expr, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		TrimExpr {
			if expr_is_agg(conn, e.source, row, params)!
				|| expr_is_agg(conn, e.character, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
		CastExpr {
			if expr_is_agg(conn, e.expr, row, params)! {
				return nested_agg_unsupported(e)
			}
		}
	}

	return false
}

fn nested_agg_unsupported(e Expr) !bool {
	return sqlstate_42601('nested aggregate functions are not supported: $e.str()')
}

fn resolve_identifiers_exprs(exprs []Expr, tables map[string]Table) ![]Expr {
	mut new_exprs := []Expr{}

	for expr in exprs {
		new_exprs << resolve_identifiers(expr, tables)!
	}

	return new_exprs
}

// resolve_identifiers will resolve the identifiers against their relevant
// tables.
fn resolve_identifiers(e Expr, tables map[string]Table) !Expr {
	match e {
		BinaryExpr {
			return BinaryExpr{resolve_identifiers(e.left, tables)!, e.op, resolve_identifiers(e.right,
				tables)!}
		}
		BetweenExpr {
			return BetweenExpr{e.not, e.symmetric, resolve_identifiers(e.expr, tables)!, resolve_identifiers(e.left,
				tables)!, resolve_identifiers(e.right, tables)!}
		}
		CallExpr {
			return CallExpr{e.function_name, resolve_identifiers_exprs(e.args, tables)!}
		}
		Identifier {
			// TODO(elliotchance): This is super hacky. It valid for there to be
			//  a "." in the deliminated name.
			parts := e.name.split('.')
			if parts.len == 3 {
				return e
			}

			if parts.len == 2 {
				return new_identifier('PUBLIC.$e.name')
			}

			for _, table in tables {
				if (table.column(e.name) or { Column{} }).name == e.name {
					return new_identifier('${table.name}.$e')
				}
			}

			// TODO(elliotchance): Need tests for table qualifier not existing.
			return e
		}
		LikeExpr {
			return LikeExpr{resolve_identifiers(e.left, tables)!, resolve_identifiers(e.right,
				tables)!, e.not}
		}
		NullExpr {
			return NullExpr{resolve_identifiers(e.expr, tables)!, e.not}
		}
		NullIfExpr {
			return NullIfExpr{resolve_identifiers(e.a, tables)!, resolve_identifiers(e.b,
				tables)!}
		}
		TruthExpr {
			return TruthExpr{resolve_identifiers(e.expr, tables)!, e.not, e.value}
		}
		CastExpr {
			return CastExpr{resolve_identifiers(e.expr, tables)!, e.target}
		}
		CoalesceExpr {
			return CoalesceExpr{e.exprs.map(resolve_identifiers(it, tables)!)}
		}
		SimilarExpr {
			return SimilarExpr{resolve_identifiers(e.left, tables)!, resolve_identifiers(e.right,
				tables)!, e.not}
		}
		SubstringExpr {
			return SubstringExpr{resolve_identifiers(e.value, tables)!, resolve_identifiers(e.from,
				tables)!, resolve_identifiers(e.@for, tables)!, e.using}
		}
		UnaryExpr {
			return UnaryExpr{e.op, resolve_identifiers(e.expr, tables)!}
		}
		CountAllExpr, Parameter, Value, NoExpr, RowExpr, QueryExpression, QualifiedAsteriskExpr,
		CurrentDateExpr, CurrentTimeExpr, CurrentTimestampExpr, LocalTimeExpr, LocalTimestampExpr,
		UntypedNullExpr {
			// These don't have any Expr properties to recurse.
			return e
		}
		TrimExpr {
			return TrimExpr{e.specification, resolve_identifiers(e.character, tables)!, resolve_identifiers(e.source,
				tables)!}
		}
	}
}
