module vsql

// ISO/IEC 9075-2:2016(E), 8.1, <predicate>
//
// # Function
//
// Specify a condition that can be evaluated to give a boolean value.
//
// # Format
//~
//~ <predicate> /* Predicate */ ::=
//~     <comparison predicate>   -> Predicate
//~   | <between predicate>      -> Predicate
//~   | <like predicate>         -> Predicate
//~   | <similar predicate>      -> Predicate
//~   | <null predicate>         -> Predicate

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

fn (e Predicate) resolve_identifiers(conn &Connection, tables map[string]Table) !Predicate {
	match e {
		ComparisonPredicate {
			return e.resolve_identifiers(conn, tables)!
		}
		BetweenPredicate {
			return e.resolve_identifiers(conn, tables)!
		}
		CharacterLikePredicate {
			return e.resolve_identifiers(conn, tables)!
		}
		SimilarPredicate {
			return e.resolve_identifiers(conn, tables)!
		}
		NullPredicate {
			return e.resolve_identifiers(conn, tables)!
		}
	}
}
