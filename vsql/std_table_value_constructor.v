// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>

module vsql

// Format
//~
//~ <table value constructor> /* SimpleTable */ ::=
//~     VALUES <row value expression list>   -> table_value_constructor
//~
//~ <row value expression list> /* []Expr */ ::=
//~     <table row value expression>           -> expr_to_list
//~   | <row value expression list>
//~     <comma> <table row value expression>   -> append_exprs1
//~
//~ <contextually typed table value constructor> /* []Expr */ ::=
//~     VALUES <contextually typed row value expression list>   -> exprs
//~
//~ <contextually typed row value expression list> /* []Expr */ ::=
//~     <contextually typed row value expression>
//~   | <contextually typed row value expression list> <comma>
//~     <contextually typed row value expression>                -> merge_expr_lists

fn parse_table_value_constructor(exprs []Expr) !SimpleTable {
	if exprs[0] is RowExpr {
		mut rows := []RowExpr{}

		for expr in exprs {
			rows << expr as RowExpr
		}

		return rows
	}

	return [RowExpr{
		exprs: exprs
	}]
}

fn parse_merge_expr_lists(exprs1 []Expr, exprs2 []Expr) ![]Expr {
	mut new_exprs := exprs1.clone()
	for expr in exprs2 {
		new_exprs << expr
	}
	return new_exprs
}

fn parse_expr_to_list(expr Expr) ![]Expr {
	return [expr]
}

fn parse_append_exprs1(element_list []Expr, element Expr) ![]Expr {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}
