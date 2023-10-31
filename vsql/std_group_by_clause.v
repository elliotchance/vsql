// ISO/IEC 9075-2:2016(E), 7.13, <group by clause>

module vsql

// Format
//~
//~ <group by clause> /* []Identifier */ ::=
//~     GROUP BY <grouping element list>   -> group_by_clause
//~
//~ <grouping element list> /* []Identifier */ ::=
//~     <grouping element>                                   -> grouping_element_list_1
//~   | <grouping element list> <comma> <grouping element>   -> grouping_element_list_2
//~
//~ <grouping element> /* Identifier */ ::=
//~     <ordinary grouping set>
//~
//~ <ordinary grouping set> /* Identifier */ ::=
//~     <grouping column reference>
//~
//~ <grouping column reference> /* Identifier */ ::=
//~     <column reference>

fn parse_group_by_clause(e []Identifier) ![]Identifier {
	return e
}

fn parse_grouping_element_list_1(expr Identifier) ![]Identifier {
	return [expr]
}

fn parse_grouping_element_list_2(element_list []Identifier, element Identifier) ![]Identifier {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}
