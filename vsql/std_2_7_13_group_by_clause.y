%%

// ISO/IEC 9075-2:2016(E), 7.13, <group by clause>
//
// Specify a grouped table derived by the application of the <group by clause>
// to the result of the previously specified clause.
//
// Only grouping column references, there's no ROLLUP, CUBE, GROUPING SETS or
// empty grouping set (T431), and no GROUP BY DISTINCT (T434).

group_by_clause:
  GROUP BY grouping_element_list { $$.v = $3.v }

grouping_element_list:
  grouping_element { $$.v = [$1.v as Identifier] }
| grouping_element_list comma grouping_element {
    $$.v = append_list($1.v as []Identifier, $3.v as Identifier)
  }

grouping_element:
  ordinary_grouping_set { $$.v = $1.v as Identifier }

ordinary_grouping_set:
  grouping_column_reference { $$.v = $1.v as Identifier }

grouping_column_reference:
  column_reference { $$.v = $1.v as Identifier }

%%
