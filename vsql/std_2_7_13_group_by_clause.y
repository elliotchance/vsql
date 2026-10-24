%%

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
