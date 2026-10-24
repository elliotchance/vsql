module vsql

// ISO/IEC 9075-2:2016(E), 7.19, <subquery>
//
// Specify a scalar value, a row, or a table derived from a <query expression>.

type TablePrimaryBody = Identifier | QueryExpression
