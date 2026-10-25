%%

predicate:
  comparison_predicate { $$.v = Predicate($1.v as ComparisonPredicate) }
| between_predicate { $$.v = Predicate($1.v as BetweenPredicate) }
| in_predicate { $$.v = Predicate($1.v as InPredicate) }
| like_predicate { $$.v = Predicate($1.v as CharacterLikePredicate) }
| similar_predicate { $$.v = Predicate($1.v as SimilarPredicate) }
| null_predicate { $$.v = Predicate($1.v as NullPredicate) }
| quantified_comparison_predicate {
    $$.v = Predicate($1.v as QuantifiedComparisonPredicate)
  }
| exists_predicate { $$.v = Predicate($1.v as ExistsPredicate) }

%%
