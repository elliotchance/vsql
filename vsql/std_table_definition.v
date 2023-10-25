// ISO/IEC 9075-2:2016(E), 11.3, <table definition>

module vsql

// Format
//~
//~ <table definition> /* CreateTableStmt */ ::=
//~     CREATE TABLE <table name> <table contents source>   -> table_definition
//~
//~ <table contents source> /* []TableElement */ ::=
//~     <table element list>
//~
//~ <table element list> /* []TableElement */ ::=
//~     <left paren>
//~     <table elements>
//~     <right paren>      -> table_element_list
//~
//~ <table element> /* TableElement */ ::=
//~     <column definition>
//~   | <table constraint definition>
//
// These are non-standard, just to simplify standard rules:
//~
//~ <table elements> /* []TableElement */ ::=
//~     <table element>                            -> table_elements1
//~   | <table elements> <comma> <table element>   -> table_elements2

fn parse_table_definition(table_name Identifier, table_contents_source []TableElement) !Stmt {
	return CreateTableStmt{table_name, table_contents_source}
}

fn parse_table_element_list(table_elements []TableElement) ![]TableElement {
	return table_elements
}

fn parse_table_elements1(table_element TableElement) ![]TableElement {
	return [table_element]
}

fn parse_table_elements2(table_elements []TableElement, table_element TableElement) ![]TableElement {
	mut new_table_elements := table_elements.clone()
	new_table_elements << table_element
	return new_table_elements
}
