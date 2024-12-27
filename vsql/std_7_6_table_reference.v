module vsql

// ISO/IEC 9075-2:2016(E), 7.6, <table reference>
//
// # Function
//
// Reference a table.
//
// # Format
//~
//~ <table reference> /* TableReference */ ::=
//~     <table factor>   -> TableReference
//~   | <joined table>   -> TableReference
//~
//~ <qualified join> /* QualifiedJoin */ ::=
//~     <table reference>
//~     JOIN <table reference> <join specification>   -> qualified_join_1
//~   | <table reference> <join type>
//~     JOIN <table reference> <join specification>   -> qualified_join_2
//~
//~ <table factor> /* TablePrimary */ ::=
//~     <table primary>
//~
//~ <table primary> /* TablePrimary */ ::=
//~     <table or query name>                          -> table_primary_identifier
//~   | <derived table>
//~   | <derived table> <correlation or recognition>   -> table_primary_derived_2
//~
//~ <correlation or recognition> /* Correlation */ ::=
//~     <correlation name>                    -> correlation_1
//~   | AS <correlation name>                 -> correlation_1
//~   | <correlation name>
//~     <parenthesized derived column list>   -> correlation_2
//~   | AS <correlation name>
//~     <parenthesized derived column list>   -> correlation_2
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
//~     <column name>                              -> column_name_list_1
//~   | <column name list> <comma> <column name>   -> column_name_list_2
//~
//~ <parenthesized derived column list> /* []Identifier */ ::=
//~     <left paren> <derived column list>
//~     <right paren>                        -> parenthesized_derived_column_list

struct Correlation {
	name    Identifier
	columns []Identifier
}

fn (c Correlation) str() string {
	if c.name.sub_entity_name == '' {
		return ''
	}

	mut s := ' AS ${c.name}'

	if c.columns.len > 0 {
		mut columns := []string{}
		for col in c.columns {
			columns << col.sub_entity_name
		}

		s += ' (${columns.join(', ')})'
	}

	return s
}

struct TablePrimary {
	body        TablePrimaryBody
	correlation Correlation
}

type TableReference = QualifiedJoin | TablePrimary

struct QualifiedJoin {
	left_table    TableReference
	join_type     string // 'INNER', 'LEFT' or 'RIGHT'
	right_table   TableReference
	specification BooleanValueExpression // ON condition
}
