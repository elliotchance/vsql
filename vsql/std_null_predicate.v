// ISO/IEC 9075-2:2016(E), 8.8, <null predicate>

module vsql

// Format
//~
//~ <null predicate> /* NullPredicate */ ::=
//~     <row value predicand> <null predicate part 2>   -> null_predicate
//~
//~ <null predicate part 2> /* bool */ ::=
//~     IS NULL       -> yes
//~   | IS NOT NULL   -> no

// NullPredicate for "IS NULL" and "IS NOT NULL".
struct NullPredicate {
	expr Expr
	not  bool
}

fn (e NullPredicate) pstr(params map[string]Value) string {
	if e.not {
		return '${e.expr.pstr(params)} IS NOT NULL'
	}

	return '${e.expr.pstr(params)} IS NULL'
}

fn (e NullPredicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	value := eval_as_value(mut conn, data, e.expr, params)!

	if e.not {
		return new_boolean_value(!value.is_null)
	}

	return new_boolean_value(value.is_null)
}

fn (e NullPredicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if expr_is_agg(conn, e.expr, row, params)! {
		return nested_agg_unsupported(Predicate(e))
	}

	return false
}

fn (e NullPredicate) resolve_identifiers(conn &Connection, tables map[string]Table) !Expr {
	return Predicate(NullPredicate{resolve_identifiers(conn, e.expr, tables)!, e.not})
}

fn parse_null_predicate(expr Expr, is_null bool) !NullPredicate {
	return NullPredicate{expr, !is_null}
}
