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
		Identifier, Parameter, Value, NoExpr, RowExpr, QualifiedAsteriskExpr, QueryExpression,
		CurrentDateExpr, CurrentTimeExpr, CurrentTimestampExpr, LocalTimeExpr, LocalTimestampExpr {
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
		SubstringExpr {
			if expr_is_agg(conn, e.value)? || expr_is_agg(conn, e.from)?
				|| expr_is_agg(conn, e.@for)? {
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

fn resolve_identifiers_exprs(exprs []Expr, tables map[string]Table) ?[]Expr {
	mut new_exprs := []Expr{}

	for expr in exprs {
		new_exprs << resolve_identifiers(expr, tables)?
	}

	return new_exprs
}

// resolve_identifiers will resolve the identifiers against their relevant
// tables.
fn resolve_identifiers(e Expr, tables map[string]Table) ?Expr {
	match e {
		BinaryExpr {
			return BinaryExpr{resolve_identifiers(e.left, tables)?, e.op, resolve_identifiers(e.right,
				tables)?}
		}
		BetweenExpr {
			return BetweenExpr{e.not, e.symmetric, resolve_identifiers(e.expr, tables)?, resolve_identifiers(e.left,
				tables)?, resolve_identifiers(e.right, tables)?}
		}
		CallExpr {
			return CallExpr{e.function_name, resolve_identifiers_exprs(e.args, tables)?}
		}
		Identifier {
			// TODO(elliotchance): This is super hacky. It valid for there to be
			//  a "." in the deliminated name.
			if e.name.contains('.') {
				return e
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
			return LikeExpr{resolve_identifiers(e.left, tables)?, resolve_identifiers(e.right,
				tables)?, e.not}
		}
		NullExpr {
			return NullExpr{resolve_identifiers(e.expr, tables)?, e.not}
		}
		SimilarExpr {
			return SimilarExpr{resolve_identifiers(e.left, tables)?, resolve_identifiers(e.right,
				tables)?, e.not}
		}
		SubstringExpr {
			return SubstringExpr{resolve_identifiers(e.value, tables)?, resolve_identifiers(e.from,
				tables)?, resolve_identifiers(e.@for, tables)?, e.using}
		}
		UnaryExpr {
			return UnaryExpr{e.op, resolve_identifiers(e.expr, tables)?}
		}
		CountAllExpr, Parameter, Value, NoExpr, RowExpr, QueryExpression, QualifiedAsteriskExpr,
		CurrentDateExpr, CurrentTimeExpr, CurrentTimestampExpr, LocalTimeExpr, LocalTimestampExpr {
			// These don't have any Expr properties to recurse.
			return e
		}
	}
}
