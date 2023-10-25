// ISO/IEC 9075-2:2016(E), 7.16, <query specification>

module vsql

// Format
//~
//~ <query specification> /* SimpleTable */ ::=
//~     SELECT
//~     <select list>
//~     <table expression>   -> query_specification
//~
//~ <select list> /* SelectList */ ::=
//~     <asterisk>                               -> asterisk
//~   | <select sublist>
//~   | <select list> <comma> <select sublist>   -> select_list2
//~
//~ <select sublist> /* SelectList */ ::=
//~     <derived column>       -> select_sublist1
//~   | <qualified asterisk>   -> select_sublist2
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

fn parse_query_specification(select_list SelectList, table_expression TableExpression) !SimpleTable {
	return SelectStmt{
		exprs: select_list
		table_expression: table_expression
		offset: NoExpr{}
		fetch: NoExpr{}
	}
}

// asterisk is a special expression used in SELECT to represent "*".
fn parse_asterisk(_ string) !SelectList {
	return AsteriskExpr(true)
}

// <select list> <comma> <select sublist>
fn parse_select_list2(select_list SelectList, columns SelectList) !SelectList {
	mut new_select_list := (select_list as []DerivedColumn).clone()
	new_select_list << (columns as []DerivedColumn)[0]
	return new_select_list
}

fn parse_select_sublist1(column DerivedColumn) !SelectList {
	return [column]
}

fn parse_select_sublist2(column QualifiedAsteriskExpr) !SelectList {
	return column
}

fn parse_qualified_asterisk(column IdentifierChain, _ string) !QualifiedAsteriskExpr {
	return QualifiedAsteriskExpr{new_column_identifier(column.identifier)!}
}

fn parse_derived_column(expr Expr) !DerivedColumn {
	return DerivedColumn{expr, Identifier{}}
}

fn parse_derived_column_as(expr Expr, as_clause Identifier) !DerivedColumn {
	return DerivedColumn{expr, as_clause}
}

fn parse_identifier(name Identifier) !Identifier {
	return name
}
