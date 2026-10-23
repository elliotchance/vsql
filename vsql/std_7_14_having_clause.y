%%

// ISO/IEC 9075-2:2016(E), 7.14, <having clause>
//
// Specify a grouped table derived by the elimination of groups that do not
// satisfy a <search condition>.

having_clause:
  HAVING search_condition { $$.v = $2.v as BooleanValueExpression }

%%
