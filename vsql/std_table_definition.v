// ISO/IEC 9075-2:2016(E), 11.3, <table definition>

module vsql

// Format
//~
//~ <table definition> /* TableDefinition */ ::=
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
//~     <table element>                            -> table_elements_1
//~   | <table elements> <comma> <table element>   -> table_elements_2

type TableElement = Column | UniqueConstraintDefinition

struct TableDefinition {
	table_name     Identifier
	table_elements []TableElement
}

fn (s TableDefinition) columns() Columns {
	mut columns := []Column{}
	for c in s.table_elements {
		if c is Column {
			columns << c
		}
	}

	return columns
}

fn parse_table_definition(table_name Identifier, table_contents_source []TableElement) !Stmt {
	return TableDefinition{table_name, table_contents_source}
}

fn parse_table_element_list(table_elements []TableElement) ![]TableElement {
	return table_elements
}

fn parse_table_elements_1(table_element TableElement) ![]TableElement {
	return [table_element]
}

fn parse_table_elements_2(table_elements []TableElement, table_element TableElement) ![]TableElement {
	mut new_table_elements := table_elements.clone()
	new_table_elements << table_element
	return new_table_elements
}
