// expr.v contains functions for examining expressions.

module vsql

// expr_is_agg returns true if the expression is or contains an aggregate
// function. That means that the value must be evaluated by the GROUP BY
// (GroupOperation)
fn expr_is_agg(conn &Connection, e Expr) ?bool {
	match e {
		BinaryExpr {
			if expr_is_agg(conn, e.left)? || expr_is_agg(conn, e.right)? {
				return nested_agg_unsupported(e)
			}
		}
		BetweenExpr {
			if expr_is_agg(conn, e.left)? || expr_is_agg(conn, e.right)? {
				return nested_agg_unsupported(e)
			}
		}
		CallExpr {
			func := conn.funcs[e.function_name] or { return sqlstate_42883(e.function_name) }

			if func.is_agg {
				return true
			}

			for arg in e.args {
				if expr_is_agg(conn, arg)? {
					return nested_agg_unsupported(e)
				}
			}
		}
		CountAllExpr {
			return true
		}
		Identifier, Parameter, Value, NoExpr, RowExpr, QueryExpression {
			return false
		}
		LikeExpr {
			if expr_is_agg(conn, e.left)? {
				return nested_agg_unsupported(e)
			}
		}
		NullExpr {
			if expr_is_agg(conn, e.expr)? {
				return nested_agg_unsupported(e)
			}
		}
		SimilarExpr {
			if expr_is_agg(conn, e.left)? {
				return nested_agg_unsupported(e)
			}
		}
		UnaryExpr {
			if expr_is_agg(conn, e.expr)? {
				return nested_agg_unsupported(e)
			}
		}
	}

	return false
}

fn nested_agg_unsupported(e Expr) ?bool {
	return sqlstate_42601('nested aggregate functions are not supported: $e.str()')
}

fn resolve_identifiers_exprs(exprs []Expr, table Table) ?[]Expr {
	mut new_exprs := []Expr{}

	for expr in exprs {
		new_exprs << resolve_identifiers(expr, table)?
	}

	return new_exprs
}

// resolve_identifiers will resolve the identifiers against their relevant
// table.
fn resolve_identifiers(e Expr, table Table) ?Expr {
	match e {
		BinaryExpr {
			return BinaryExpr{resolve_identifiers(e.left, table)?, e.op, resolve_identifiers(e.right,
				table)?}
		}
		BetweenExpr {
			return BetweenExpr{e.not, e.symmetric, resolve_identifiers(e.expr, table)?, resolve_identifiers(e.left,
				table)?, resolve_identifiers(e.right, table)?}
		}
		CallExpr {
			return CallExpr{e.function_name, resolve_identifiers_exprs(e.args, table)?}
		}
		Identifier {
			return new_identifier('${table.name}.$e')
		}
		LikeExpr {
			return LikeExpr{resolve_identifiers(e.left, table)?, resolve_identifiers(e.right,
				table)?, e.not}
		}
		NullExpr {
			return NullExpr{resolve_identifiers(e.expr, table)?, e.not}
		}
		SimilarExpr {
			return SimilarExpr{resolve_identifiers(e.left, table)?, resolve_identifiers(e.right,
				table)?, e.not}
		}
		UnaryExpr {
			return UnaryExpr{e.op, resolve_identifiers(e.expr, table)?}
		}
		CountAllExpr, Parameter, Value, NoExpr, RowExpr, QueryExpression {
			// These don't have any Expr properties to recurse.
			return e
		}
	}
}
