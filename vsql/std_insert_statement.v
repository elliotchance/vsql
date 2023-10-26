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
//~ <insert columns and source> /* InsertStatement */ ::=
//~   <from constructor>
//~
//~ <from constructor> /* InsertStatement */ ::=
//~     <left paren> <insert column list> <right paren>
//~     <contextually typed table value constructor>   -> from_constructor
//~
//~ <insert column list> /* []Identifier */ ::=
//~     <column name list>

struct InsertStatement {
	table_name Identifier
	columns    []Identifier
	values     []ContextuallyTypedRowValueConstructor
}

fn parse_insert_statement(insertion_target Identifier, stmt InsertStatement) !Stmt {
	return InsertStatement{insertion_target, stmt.columns, stmt.values}
}

fn parse_from_constructor(columns []Identifier, values []ContextuallyTypedRowValueConstructor) !InsertStatement {
	return InsertStatement{
		columns: columns
		values: values
	}
}
