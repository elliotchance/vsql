// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>

module vsql

// Format
//~
//~ <SQL schema statement> /* Stmt */ ::=
//~     <SQL schema definition statement>
//~   | <SQL schema manipulation statement>
//~
//~ <SQL schema definition statement> /* Stmt */ ::=
//~     <schema definition>
//~   | <table definition>
//~   | <sequence generator definition>
//~
//~ <SQL schema manipulation statement> /* Stmt */ ::=
//~     <drop schema statement>
//~   | <drop table statement>
//~   | <alter sequence generator statement>
//~   | <drop sequence generator statement>
//~
//~ <SQL transaction statement> /* Stmt */ ::=
//~     <start transaction statement>
//~   | <commit statement>
//~   | <rollback statement>
//~
//~ <SQL session statement> /* Stmt */ ::=
//~     <set schema statement>
//~   | <set catalog statement>
