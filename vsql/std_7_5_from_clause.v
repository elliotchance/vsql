module vsql

// ISO/IEC 9075-2:2016(E), 7.5, <from clause>
//
// # Function
//
// Specify a table derived from one or more tables.
//
// # Format
//~
//~ <from clause> /* TableReference */ ::=
//~     FROM <table reference list>   -> from_clause
//~
//~ <table reference list> /* TableReference */ ::=
//~     <table reference>
