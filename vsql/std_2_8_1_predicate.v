module vsql

// ISO/IEC 9075-2:2023(E), 8.1, <predicate>
//
// Specify a condition that can be evaluated to give a boolean value.

type Predicate = BetweenPredicate
	| CharacterLikePredicate
	| ComparisonPredicate
	| DistinctPredicate
	| ExistsPredicate
	| InPredicate
	| NullPredicate
	| OverlapsPredicate
	| QuantifiedComparisonPredicate
	| SimilarPredicate
	| UniquePredicate

fn (e Predicate) pstr(params map[string]Value) string {
	return match e {
		ComparisonPredicate, BetweenPredicate, InPredicate, CharacterLikePredicate,
		SimilarPredicate, NullPredicate, QuantifiedComparisonPredicate, ExistsPredicate,
		UniquePredicate, DistinctPredicate, OverlapsPredicate {
			e.pstr(params)
		}
	}
}

fn (e Predicate) compile(mut c Compiler) !CompileResult {
	// Only a comparison or BETWEEN of this predicate can be retrospectively
	// deterministic, not one in a CASE that's one of its comparands. A quantified
	// comparison can't be, since a CHECK can't contain a subquery (Feature F671).
	retrospective := c.retrospective
	c.retrospective = false
	defer {
		c.retrospective = retrospective
	}

	match e {
		ComparisonPredicate {
			return e.compile_comparison(mut c, retrospective)!
		}
		BetweenPredicate {
			return e.compile_between(mut c, retrospective)!
		}
		InPredicate, CharacterLikePredicate, SimilarPredicate, NullPredicate,
		QuantifiedComparisonPredicate, ExistsPredicate, UniquePredicate, DistinctPredicate,
		OverlapsPredicate {
			return e.compile(mut c)!
		}
	}
}
