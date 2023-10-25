// ISO/IEC 9075-2:2016(E), 7.6, <table reference>

module vsql

// Format
//~
//~ <table reference> /* TableReference */ ::=
//~     <table factor>   -> table_factor
//~   | <joined table>   -> joined_table
//~
//~ <qualified join> /* QualifiedJoin */ ::=
//~     <table reference>
//~     JOIN <table reference> <join specification>   -> qualified_join1
//~   | <table reference> <join type>
//~     JOIN <table reference> <join specification>   -> qualified_join2
//~
//~ <table factor> /* TablePrimary */ ::=
//~     <table primary>
//~
//~ <table primary> /* TablePrimary */ ::=
//~     <table or query name>                          -> table_primary_identifier
//~   | <derived table>                                -> table_primary_derived1
//~   | <derived table> <correlation or recognition>   -> table_primary_derived2
//~
//~ <correlation or recognition> /* Correlation */ ::=
//~     <correlation name>                    -> correlation1
//~   | AS <correlation name>                 -> correlation1
//~   | <correlation name>
//~     <parenthesized derived column list>   -> correlation2
//~   | AS <correlation name>
//~     <parenthesized derived column list>   -> correlation2
//~
//~ <derived table> /* TablePrimary */ ::=
//~     <table subquery>
//~
//~ <table or query name> /* Identifier */ ::=
//~     <table name>
//~
//~ <derived column list> /* []Identifier */ ::=
//~     <column name list>
//~
//~ <column name list> /* []Identifier */ ::=
//~     <column name>                              -> column_name_list1
//~   | <column name list> <comma> <column name>   -> column_name_list2
//~
//~ <parenthesized derived column list> /* []Identifier */ ::=
//~     <left paren> <derived column list>
//~     <right paren>                        -> parenthesized_derived_column_list

fn parse_table_factor(p TablePrimary) !TableReference {
	return p
}

fn parse_joined_table(join QualifiedJoin) !TableReference {
	return join
}

fn parse_qualified_join1(left_table TableReference, right_table TableReference, specification Expr) !QualifiedJoin {
	return QualifiedJoin{left_table, 'INNER', right_table, specification}
}

fn parse_qualified_join2(left_table TableReference, join_type string, right_table TableReference, specification Expr) !QualifiedJoin {
	return QualifiedJoin{left_table, join_type, right_table, specification}
}

fn parse_table_primary_identifier(name Identifier) !TablePrimary {
	return TablePrimary{
		body: name
	}
}

fn parse_table_primary_derived1(body TablePrimary) !TablePrimary {
	return body
}

fn parse_table_primary_derived2(body TablePrimary, correlation Correlation) !TablePrimary {
	return TablePrimary{
		body: body.body
		correlation: correlation
	}
}

fn parse_column_name_list1(column_name Identifier) ![]Identifier {
	return [column_name]
}

fn parse_column_name_list2(column_name_list []Identifier, column_name Identifier) ![]Identifier {
	mut new_columns := column_name_list.clone()
	new_columns << column_name
	return new_columns
}

fn parse_correlation1(name Identifier) !Correlation {
	return Correlation{
		name: name
	}
}

fn parse_correlation2(name Identifier, columns []Identifier) !Correlation {
	return Correlation{
		name: name
		columns: columns
	}
}

fn parse_parenthesized_derived_column_list(columns []Identifier) ![]Identifier {
	return columns
}
