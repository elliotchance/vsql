%%

// A <row subquery> (F641) isn't supported yet, so a subquery in a row is always
// a <scalar subquery>.
scalar_subquery:
  subquery { $$.v = new_subquery(($1.v as TablePrimary).body as QueryExpression) }

table_subquery:
  subquery { $$.v = $1.v as TablePrimary }

// ((SELECT 1)) is a subquery of the parenthesized query (SELECT 1), or the
// scalar subquery (SELECT 1) in parentheses. Both are the same, but the parser
// can't always know which one it is, because ( ((SELECT 1)) UNION SELECT 2 ) is
// a subquery of a UNION, and there can be any number of parentheses before the
// UNION. So a right_paren after a parenthesized_query_expression is always part
// of the parenthesized_query_expression, see %prec SUBQUERY in grammar.y.
subquery:
  parenthesized_query_expression %prec SUBQUERY {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .subquery)
    $$.v = TablePrimary{
      body: $1.v as QueryExpression
    }
  }

%%
