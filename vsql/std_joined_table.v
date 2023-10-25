// ISO/IEC 9075-2:2016(E), 7.10, <joined table>

module vsql

// Format
//~
//~ <joined table> /* QualifiedJoin */ ::=
//~     <qualified join>
//~
//~ <join specification> /* Expr */ ::=
//~     <join condition>
//~
//~ <join condition> /* Expr */ ::=
//~     ON <search condition>   -> expr
//~
//~ <join type> /* string */ ::=
//~     INNER
//~   | <outer join type>
//~   | <outer join type> OUTER   -> string
//~
//~ <outer join type> /* string */ ::=
//~     LEFT
//~   | RIGHT
