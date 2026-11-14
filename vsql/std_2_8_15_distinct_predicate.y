%%

// ISO/IEC 9075-2:2023(E), 8.15, <distinct predicate>
//
// <row value predicand 3> and <row value predicand 4> are only a
// <row value predicand>, so they're used directly to avoid a conflict.
//
// ISO/IEC 9075-2:2023(E), 8.15, <distinct predicate>, Conformance Rules, 1
// and 2
distinct_predicate:
  row_value_predicand distinct_predicate_part_2 {
    flag(mut yylex, 'T151')
    part2 := $2.v as DistinctPredicatePart2
    if part2.not {
      flag(mut yylex, 'T152')
    }
    $$.v = yy_box(DistinctPredicate{$1.v as RowValueConstructorPredicand, part2.right,
      part2.not})
  }

distinct_predicate_part_2:
  IS DISTINCT FROM row_value_predicand {
    $$.v = yy_box(DistinctPredicatePart2{$4.v as RowValueConstructorPredicand, false})
  }
| IS NOT DISTINCT FROM row_value_predicand {
    $$.v = yy_box(DistinctPredicatePart2{$5.v as RowValueConstructorPredicand, true})
  }

%%
