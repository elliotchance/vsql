%%

// ISO/IEC 9075-2:2023, 8.13, <match predicate>, Conformance Rules, 1
match_predicate:
  row_value_predicand match_predicate_part_2 {
    flag(mut yylex, 'F741')
    $$.v = yy_box(MatchPredicate{
      ...$2.v as MatchPredicate
      expr: $1.v as RowValueConstructorPredicand
    })
  }

// ISO/IEC 9075-2:2023, 8.13, <match predicate>, Syntax Rules, 3
match_predicate_part_2:
  MATCH table_subquery {
    $$.v = yy_box(new_match_predicate(false, 'SIMPLE', $2.v as TablePrimary))
  }
| MATCH UNIQUE table_subquery {
    $$.v = yy_box(new_match_predicate(true, 'SIMPLE', $3.v as TablePrimary))
  }
| MATCH match_type table_subquery {
    $$.v = yy_box(new_match_predicate(false, $2.v as string, $3.v as TablePrimary))
  }
| MATCH UNIQUE match_type table_subquery {
    $$.v = yy_box(new_match_predicate(true, $3.v as string, $4.v as TablePrimary))
  }

%%
