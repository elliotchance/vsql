// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>

module vsql

// Format
//~
//~ <preparable statement> /* Stmt */ ::=
//~     <preparable SQL data statement>
//~   | <preparable SQL schema statement>
//~   | <preparable SQL transaction statement>
//~   | <preparable SQL session statement>
//~
//~ <preparable SQL data statement> /* Stmt */ ::=
//~     <delete statement: searched>
//~   | <insert statement>
//~   | <dynamic select statement>
//~   | <update statement: searched>
//~
//~ <preparable SQL schema statement> /* Stmt */ ::=
//~     <SQL schema statement>
//~
//~ <preparable SQL transaction statement> /* Stmt */ ::=
//~   <SQL transaction statement>
//~
//~ <preparable SQL session statement> /* Stmt */ ::=
//~     <SQL session statement>
//~
//~ <dynamic select statement> /* Stmt */ ::=
//~     <cursor specification>
