module vsql

// ISO/IEC 9075-2:2016(E), 7.16, <query specification>
//
// # Function
//
// Specify a table derived from the result of a <table expression>.
//
// # Format
//~
//~ <query specification> /* SimpleTable */ ::=
//~     SELECT
//~     <select list>
//~     <table expression>   -> query_specification
//~
//~ <select list> /* SelectList */ ::=
//~     <asterisk>                               -> asterisk
//~   | <select sublist>
//~   | <select list> <comma> <select sublist>   -> select_list_2
//~
//~ <select sublist> /* SelectList */ ::=
//~     <derived column>       -> select_sublist_1
//~   | <qualified asterisk>   -> SelectList
//~
//~ <qualified asterisk> /* QualifiedAsteriskExpr */ ::=
//~     <asterisked identifier chain> <period> <asterisk>   -> qualified_asterisk
//~
//~ <asterisked identifier chain> /* IdentifierChain */ ::=
//~     <asterisked identifier>
//~
//~ <asterisked identifier> /* IdentifierChain */ ::=
//~     <identifier>
//~
//~ <derived column> /* DerivedColumn */ ::=
//~     <value expression>               -> derived_column
//~   | <value expression> <as clause>   -> derived_column_as
//~
//~ <as clause> /* Identifier */ ::=
//~     AS <column name>   -> identifier
//~   | <column name>

struct DerivedColumn {
	expr      ValueExpression
	as_clause Identifier // will be empty if not provided
}

type SelectList = AsteriskExpr | QualifiedAsteriskExpr | []DerivedColumn

type AsteriskExpr = bool

struct QualifiedAsteriskExpr {
	table_name Identifier
}

fn (e QualifiedAsteriskExpr) str() string {
	return '${e.table_name}.*'
}

struct QuerySpecification {
	exprs            SelectList
	table_expression TableExpression
	offset           ?ValueExpression
	fetch            ?ValueExpression
}

fn parse_query_specification(select_list SelectList, table_expression TableExpression) !SimpleTable {
	return QuerySpecification{
		exprs:            select_list
		table_expression: table_expression
	}
}

// asterisk is a special expression used in SELECT to represent "*".
fn parse_asterisk(_ string) !SelectList {
	return AsteriskExpr(true)
}

fn parse_select_list_2(select_list SelectList, columns SelectList) !SelectList {
	mut new_select_list := (select_list as []DerivedColumn).clone()
	new_select_list << (columns as []DerivedColumn)[0]
	return new_select_list
}

fn parse_select_sublist_1(column DerivedColumn) !SelectList {
	return [column]
}

fn parse_qualified_asterisk(column IdentifierChain, _ string) !QualifiedAsteriskExpr {
	return QualifiedAsteriskExpr{new_column_identifier(column.identifier)!}
}

fn parse_derived_column(expr ValueExpression) !DerivedColumn {
	return DerivedColumn{expr, Identifier{}}
}

fn parse_derived_column_as(expr ValueExpression, as_clause Identifier) !DerivedColumn {
	return DerivedColumn{expr, as_clause}
}

fn parse_identifier(name Identifier) !Identifier {
	return name
}
