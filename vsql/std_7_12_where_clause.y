%%

// ISO/IEC 9075-2:2016(E), 7.12, <where clause>
//
// Specify a table derived by the application of a <search condition> to the
// result of the preceding <from clause>.

where_clause:
  WHERE search_condition { $$.v = $2.v as BooleanValueExpression }

%%
