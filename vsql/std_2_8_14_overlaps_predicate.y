%%

overlaps_predicate:
  row_value_predicand overlaps_predicate_part_2 {
    $$.v = yy_box(OverlapsPredicate{
      left:  $1.v as RowValueConstructorPredicand
      right: $2.v as RowValueConstructorPredicand
    })
  }

overlaps_predicate_part_2:
  OVERLAPS row_value_predicand {
    // ISO/IEC 9075-2:2016(E), 8.14, <overlaps predicate>, Conformance Rules, 1
    flag(mut yylex, 'F053')
    $$.v = $2.v
  }

%%
