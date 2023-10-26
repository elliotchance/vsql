// ISO/IEC 9075-2:2016(E), 7.10, <joined table>

module vsql

// Format
//~
//~ <joined table> /* QualifiedJoin */ ::=
//~     <qualified join>
//~
//~ <join specification> /* BooleanValueExpression */ ::=
//~     <join condition>
//~
//~ <join condition> /* BooleanValueExpression */ ::=
//~     ON <search condition>   -> join_condition
//~
//~ <join type> /* string */ ::=
//~     INNER
//~   | <outer join type>
//~   | <outer join type> OUTER   -> string
//~
//~ <outer join type> /* string */ ::=
//~     LEFT
//~   | RIGHT

fn parse_join_condition(expr BooleanValueExpression) !BooleanValueExpression {
	return expr
}
