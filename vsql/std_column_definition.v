module vsql

// ISO/IEC 9075-2:2016(E), 11.4, <column definition>
//
// # Function
//
// Define a column of a base table.
//
// # Format
//~
//~ <column definition> /* TableElement */ ::=
//~     <column name> <data type or domain name>   -> column_definition_1
//~   | <column name> <data type or domain name>
//~     <column constraint definition>             -> column_definition_2
//~
//~ <data type or domain name> /* Type */ ::=
//~     <data type>
//~
//~ <column constraint definition> /* bool */ ::=
//~     <column constraint>
//~
//~ <column constraint> /* bool */ ::=
//~     NOT NULL   -> yes

fn parse_column_definition_1(column_name Identifier, data_type Type) !TableElement {
	return Column{column_name, data_type, false}
}

fn parse_column_definition_2(column_name Identifier, data_type Type, constraint bool) !TableElement {
	return Column{column_name, data_type, constraint}
}
