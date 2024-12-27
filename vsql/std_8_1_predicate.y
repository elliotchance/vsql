%%

predicate:
  comparison_predicate { $$.v = Predicate($1.v as ComparisonPredicate) }
| between_predicate { $$.v = Predicate($1.v as BetweenPredicate) }
| like_predicate { $$.v = Predicate($1.v as CharacterLikePredicate) }
| similar_predicate { $$.v = Predicate($1.v as SimilarPredicate) }
| null_predicate { $$.v = Predicate($1.v as NullPredicate) }

%%
