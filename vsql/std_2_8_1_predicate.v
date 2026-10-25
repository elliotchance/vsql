module vsql

// ISO/IEC 9075-2:2016(E), 8.1, <predicate>
//
// Specify a condition that can be evaluated to give a boolean value.

type Predicate = BetweenPredicate
	| CharacterLikePredicate
	| ComparisonPredicate
	| ExistsPredicate
	| InPredicate
	| NullPredicate
	| SimilarPredicate

fn (e Predicate) pstr(params map[string]Value) string {
	return match e {
		ComparisonPredicate, BetweenPredicate, InPredicate, CharacterLikePredicate,
		SimilarPredicate, NullPredicate, ExistsPredicate {
			e.pstr(params)
		}
	}
}

fn (e Predicate) compile(mut c Compiler) !CompileResult {
	match e {
		ComparisonPredicate, BetweenPredicate, InPredicate, CharacterLikePredicate,
		SimilarPredicate, NullPredicate, ExistsPredicate {
			return e.compile(mut c)!
		}
	}
}
