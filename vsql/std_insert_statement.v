// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>

module vsql

// Format
//~
//~ <insert statement> /* Stmt */ ::=
//~     INSERT INTO
//~     <insertion target>
//~     <insert columns and source>   -> insert_statement
//~
//~ <insertion target> /* Identifier */ ::=
//~     <table name>
//~
//~ <insert columns and source> /* InsertStmt */ ::=
//~   <from constructor>
//~
//~ <from constructor> /* InsertStmt */ ::=
//~     <left paren> <insert column list> <right paren>
//~     <contextually typed table value constructor>   -> from_constructor
//~
//~ <insert column list> /* []Identifier */ ::=
//~     <column name list>

fn parse_insert_statement(insertion_target Identifier, stmt InsertStmt) !Stmt {
	return InsertStmt{insertion_target, stmt.columns, stmt.values}
}

fn parse_from_constructor(columns []Identifier, values []Expr) !InsertStmt {
	return InsertStmt{
		columns: columns
		values: values
	}
}
