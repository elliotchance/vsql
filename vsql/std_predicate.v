// ISO/IEC 9075-2:2016(E), 8.1, <predicate>

module vsql

// Format
//~
//~ <predicate> /* Expr */ ::=
//~     <comparison predicate>   -> predicate_1
//~   | <between predicate>      -> predicate_2
//~   | <like predicate>         -> predicate_3
//~   | <similar predicate>      -> predicate_4
//~   | <null predicate>         -> predicate_5

type Predicate = BetweenPredicate
	| CharacterLikePredicate
	| ComparisonPredicate
	| NullPredicate
	| SimilarPredicate

fn (e Predicate) pstr(params map[string]Value) string {
	return match e {
		ComparisonPredicate, BetweenPredicate, CharacterLikePredicate, SimilarPredicate,
		NullPredicate {
			e.pstr(params)
		}
	}
}

fn (e Predicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		ComparisonPredicate, BetweenPredicate, CharacterLikePredicate, SimilarPredicate,
		NullPredicate {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e Predicate) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	// The result of a predicate is always a BOOLEAN.
	return new_type('BOOLEAN', 0, 0)
}

fn (e Predicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		ComparisonPredicate, BetweenPredicate, CharacterLikePredicate, SimilarPredicate,
		NullPredicate {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e Predicate) resolve_identifiers(conn &Connection, tables map[string]Table) !Expr {
	return match e {
		ComparisonPredicate, BetweenPredicate, CharacterLikePredicate, SimilarPredicate,
		NullPredicate {
			e.resolve_identifiers(conn, tables)!
		}
	}
}

fn parse_predicate_1(predicate ComparisonPredicate) !Expr {
	return Predicate(predicate)
}

fn parse_predicate_2(predicate BetweenPredicate) !Expr {
	return Predicate(predicate)
}

fn parse_predicate_3(predicate CharacterLikePredicate) !Expr {
	return Predicate(predicate)
}

fn parse_predicate_4(predicate SimilarPredicate) !Expr {
	return Predicate(predicate)
}

fn parse_predicate_5(predicate NullPredicate) !Expr {
	return Predicate(predicate)
}
