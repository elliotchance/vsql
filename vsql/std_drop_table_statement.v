// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>

module vsql

// Format
//~
//~ <drop table statement> /* Stmt */ ::=
//~     DROP TABLE <table name>   -> drop_table_statement

fn parse_drop_table_statement(table_name Identifier) !Stmt {
	return DropTableStmt{table_name}
}
