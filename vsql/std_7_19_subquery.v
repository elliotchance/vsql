module vsql

// ISO/IEC 9075-2:2016(E), 7.19, <subquery>
//
// # Function
//
// Specify a scalar value, a row, or a table derived from a <query expression>.
//
// # Format
//~
//~ <row subquery> /* QueryExpression */ ::=
//~     <subquery>
//~
//~ <table subquery> /* TablePrimary */ ::=
//~     <subquery>
//~
//~ <subquery> /* TablePrimaryBody */ ::=
//~     <left paren> <query expression> <right paren>   -> subquery

type TablePrimaryBody = Identifier | QueryExpression
