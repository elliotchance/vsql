// parse.vs contains all the parse methods called by the Earley parser
// (see earley.v) that tranform the SQL syntax (see grammar.v) into the AST tree
// (see ast.v).

module vsql

fn parse_binary_expr(left Expr, op string, right Expr) ?Expr {
	return BinaryExpr{left, op, right}
}

fn parse_query_specification(select_list SelectList, table_expression TableExpression) ?SimpleTable {
	return SelectStmt{
		exprs: select_list
		table_expression: table_expression
		offset: NoExpr{}
		fetch: NoExpr{}
	}
}

fn parse_select_sublist(column DerivedColumn) ?SelectList {
	return [column]
}

fn parse_derived_column(expr Expr) ?DerivedColumn {
	return DerivedColumn{expr, Identifier{}}
}

fn parse_derived_column_as(expr Expr, as_clause Identifier) ?DerivedColumn {
	return DerivedColumn{expr, as_clause}
}

fn parse_table_expression(from_clause TablePrimary) ?TableExpression {
	return TableExpression{from_clause, NoExpr{}}
}

fn parse_table_expression_where(from_clause TablePrimary, where Expr) ?TableExpression {
	return TableExpression{from_clause, where}
}

fn parse_from_clause(name TablePrimary) ?TablePrimary {
	return name
}

fn parse_table_definition(table_name Identifier, table_contents_source []TableElement) ?Stmt {
	return CreateTableStmt{table_name.name, table_contents_source}
}

fn parse_table_elements1(table_element TableElement) ?[]TableElement {
	return [table_element]
}

fn parse_table_elements2(table_elements []TableElement, table_element TableElement) ?[]TableElement {
	mut new_table_elements := table_elements.clone()
	new_table_elements << table_element
	return new_table_elements
}

fn parse_column_definition1(column_name Identifier, data_type Type) ?TableElement {
	return Column{column_name.name, data_type, false}
}

fn parse_column_definition2(column_name Identifier, data_type Type, constraint bool) ?TableElement {
	return Column{column_name.name, data_type, constraint}
}

fn parse_bigint() ?Type {
	return new_type('BIGINT', 0)
}

fn parse_integer() ?Type {
	return new_type('INTEGER', 0)
}

fn parse_smallint() ?Type {
	return new_type('SMALLINT', 0)
}

fn parse_varchar(length Value) ?Type {
	return new_type('CHARACTER VARYING', int(length.f64_value))
}

fn parse_character_n(length Value) ?Type {
	return new_type('CHARACTER', int(length.f64_value))
}

fn parse_character() ?Type {
	return new_type('CHARACTER', 1)
}

fn parse_double_precision() ?Type {
	return new_type('DOUBLE PRECISION', 0)
}

fn parse_float_n(length Value) ?Type {
	return new_type('FLOAT', int(length.f64_value))
}

fn parse_float() ?Type {
	return new_type('FLOAT', 0)
}

fn parse_real() ?Type {
	return new_type('REAL', 0)
}

fn parse_drop_table_statement(table_name Identifier) ?Stmt {
	return DropTableStmt{table_name.name}
}

fn parse_table_element_list(table_elements []TableElement) ?[]TableElement {
	return table_elements
}

fn parse_insert_statement(insertion_target Identifier, stmt InsertStmt) ?Stmt {
	return InsertStmt{insertion_target.name, stmt.columns, stmt.values}
}

fn parse_from_constructor(columns []Identifier, values []Expr) ?InsertStmt {
	return InsertStmt{'', columns, values}
}

fn parse_column_name_list1(column_name Identifier) ?[]Identifier {
	return [column_name]
}

fn parse_column_name_list2(column_name_list []Identifier, column_name Identifier) ?[]Identifier {
	mut new_columns := column_name_list.clone()
	new_columns << column_name
	return new_columns
}

fn parse_merge_expr_lists(exprs1 []Expr, exprs2 []Expr) ?[]Expr {
	mut new_exprs := exprs1.clone()
	for expr in exprs2 {
		new_exprs << expr
	}
	return new_exprs
}

fn parse_expr_to_list(expr Expr) ?[]Expr {
	return [expr]
}

fn parse_append_exprs1(element_list []Expr, element Expr) ?[]Expr {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}

fn parse_append_exprs2(element Expr, element_list []Expr) ?[]Expr {
	mut new_list := []Expr{}
	new_list << element
	for e in element_list {
		new_list << e
	}

	return new_list
}

fn parse_expr(e Expr) ?Expr {
	return e
}

fn parse_identifier(name Identifier) ?Identifier {
	return name
}

fn parse_exprs(e []Expr) ?[]Expr {
	return e
}

fn parse_yes() ?bool {
	return true
}

fn parse_no() ?bool {
	return false
}

fn parse_null_predicate(expr Expr, is_null bool) ?Expr {
	return NullExpr{expr, !is_null}
}

fn parse_value_to_expr(v Value) ?Expr {
	return v
}

fn parse_identifier_to_expr(name Identifier) ?Expr {
	return name
}

fn parse_null() ?Expr {
	return new_null_value()
}

// asterisk is a special expression used in SELECT to represent "*".
fn parse_asterisk(_ string) ?SelectList {
	return AsteriskExpr(true)
}

fn parse_abs(expr Expr) ?Expr {
	return CallExpr{'ABS', [expr]}
}

fn parse_sign_expr(sign string, expr Expr) ?Expr {
	if sign == '-' {
		return UnaryExpr{'-', expr}
	}

	return expr
}

fn parse_value(v Value) ?Value {
	return v
}

fn parse_exact_numeric_literal1(a Value, b Value) ?Value {
	return new_double_precision_value('${a.f64_value}.$b.f64_value'.f64())
}

fn parse_exact_numeric_literal2(a Value) ?Value {
	return new_double_precision_value('0.$a.f64_value'.f64())
}

// <select list> <comma> <select sublist>
fn parse_select_list2(select_list SelectList, columns SelectList) ?SelectList {
	mut new_select_list := (select_list as []DerivedColumn).clone()
	new_select_list << (columns as []DerivedColumn)[0]
	return new_select_list
}

fn parse_trig_func(function_name string, expr Expr) ?Expr {
	return CallExpr{function_name, [expr]}
}

fn parse_sqrt(expr Expr) ?Expr {
	return CallExpr{'SQRT', [expr]}
}

fn parse_ln(expr Expr) ?Expr {
	return CallExpr{'LN', [expr]}
}

fn parse_floor(expr Expr) ?Expr {
	return CallExpr{'FLOOR', [expr]}
}

fn parse_ceiling(expr Expr) ?Expr {
	return CallExpr{'CEILING', [expr]}
}

fn parse_log10(expr Expr) ?Expr {
	return CallExpr{'LOG10', [expr]}
}

fn parse_exp(expr Expr) ?Expr {
	return CallExpr{'EXP', [expr]}
}

fn parse_power(a Expr, b Expr) ?Expr {
	return CallExpr{'POWER', [a, b]}
}

fn parse_mod(a Expr, b Expr) ?Expr {
	return CallExpr{'MOD', [a, b]}
}

fn parse_delete_statement(table_name Identifier) ?Stmt {
	return DeleteStmt{table_name.name, NoExpr{}}
}

fn parse_delete_statement_where(table_name Identifier, where Expr) ?Stmt {
	return DeleteStmt{table_name.name, where}
}

fn parse_comparison_part(op string, expr Expr) ?ComparisonPredicatePart2 {
	return ComparisonPredicatePart2{op, expr}
}

fn parse_comparison(expr Expr, comp ComparisonPredicatePart2) ?Expr {
	return BinaryExpr{expr, comp.op, comp.expr}
}

fn parse_boolean_type() ?Type {
	return new_type('BOOLEAN', 0)
}

fn parse_true() ?Value {
	return new_boolean_value(true)
}

fn parse_false() ?Value {
	return new_boolean_value(false)
}

fn parse_unknown() ?Value {
	return new_unknown_value()
}

fn parse_update_statement(target_table Identifier, set_clause_list map[string]Expr) ?Stmt {
	return UpdateStmt{target_table.name, set_clause_list, NoExpr{}}
}

fn parse_update_statement_where(target_table Identifier, set_clause_list map[string]Expr, where Expr) ?Stmt {
	return UpdateStmt{target_table.name, set_clause_list, where}
}

fn parse_set_clause_append(set_clause_list map[string]Expr, set_clause map[string]Expr) ?map[string]Expr {
	mut new_set_clause_list := set_clause_list.clone()

	// Even though there will only be one of these.
	for k, v in set_clause {
		new_set_clause_list[k] = v
	}

	return new_set_clause_list
}

fn parse_set_clause(target Identifier, update_source Expr) ?map[string]Expr {
	return {
		target.name: update_source
	}
}

fn parse_concatenation(a Expr, b Expr) ?Expr {
	return BinaryExpr{a, '||', b}
}

fn parse_and(left Expr, right Expr) ?Expr {
	return BinaryExpr{left, 'AND', right}
}

fn parse_or(left Expr, right Expr) ?Expr {
	return BinaryExpr{left, 'OR', right}
}

fn parse_not(expr Expr) ?Expr {
	return UnaryExpr{'NOT', expr}
}

fn parse_fetch_first_clause(quantity Expr) ?Expr {
	return quantity
}

fn parse_empty() ?Expr {
	return NoExpr{}
}

fn parse_query_expression(body SimpleTable) ?QueryExpression {
	return QueryExpression{
		body: body
		offset: NoExpr{}
		fetch: NoExpr{}
	}
}

fn parse_query_expression_offset(body SimpleTable, offset Expr) ?QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		fetch: NoExpr{}
	}
}

fn parse_query_expression_fetch(body SimpleTable, fetch Expr) ?QueryExpression {
	return QueryExpression{
		body: body
		offset: NoExpr{}
		fetch: fetch
	}
}

fn parse_query_expression_offset_fetch(body SimpleTable, offset Expr, fetch Expr) ?QueryExpression {
	return QueryExpression{
		body: body
		offset: offset
		fetch: fetch
	}
}

fn parse_empty_exprs() ?[]Expr {
	return []Expr{}
}

fn parse_routine_invocation(name Identifier, args []Expr) ?Expr {
	return CallExpr{name.name, args}
}

fn parse_host_parameter_name(name Identifier) ?Expr {
	return Parameter{name.original}
}

fn parse_unique_constraint_definition(columns []Identifier) ?TableElement {
	return UniqueConstraintDefinition{columns}
}

fn parse_ignore() ?bool {
	return false
}

fn parse_position(expr1 Expr, expr2 Expr) ?Expr {
	return CallExpr{'POSITION', [expr1, expr2]}
}

fn parse_char_length(e Expr) ?Expr {
	return CallExpr{'CHAR_LENGTH', [e]}
}

fn parse_octet_length(e Expr) ?Expr {
	return CallExpr{'OCTET_LENGTH', [e]}
}

fn parse_start_transaction() ?Stmt {
	return StartTransactionStmt{}
}

fn parse_commit() ?Stmt {
	return CommitStmt{}
}

fn parse_rollback() ?Stmt {
	return RollbackStmt{}
}

fn parse_between(expr Expr, between BetweenExpr) ?Expr {
	return BetweenExpr{
		not: between.not
		symmetric: between.symmetric
		expr: expr
		left: between.left
		right: between.right
	}
}

fn parse_between1(is_true bool, left Expr, right Expr) ?BetweenExpr {
	// false between ASYMMETRIC by default.
	return parse_between2(is_true, false, left, right)
}

fn parse_between2(is_true bool, symmetric bool, left Expr, right Expr) ?BetweenExpr {
	return BetweenExpr{
		not: !is_true
		symmetric: symmetric
		left: left
		right: right
	}
}

fn parse_table_value_constructor(exprs []Expr) ?SimpleTable {
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

fn parse_table_primary_identifier(name Identifier) ?TablePrimary {
	return TablePrimary{
		body: name
	}
}

fn parse_subquery(stmt QueryExpression) ?TablePrimary {
	return TablePrimary{
		body: stmt
	}
}

fn parse_cursor_specification(stmt QueryExpression) ?Stmt {
	return stmt
}

fn parse_table_primary_derived1(body TablePrimary) ?TablePrimary {
	return body
}

fn parse_table_primary_derived2(body TablePrimary, correlation Correlation) ?TablePrimary {
	return TablePrimary{
		body: body.body
		correlation: correlation
	}
}

fn parse_parenthesized_derived_column_list(columns []Identifier) ?[]Identifier {
	return columns
}

fn parse_correlation1(name Identifier) ?Correlation {
	return Correlation{
		name: name
	}
}

fn parse_correlation2(name Identifier, columns []Identifier) ?Correlation {
	return Correlation{
		name: name
		columns: columns
	}
}

fn parse_row_constructor1(exprs []Expr) ?Expr {
	return RowExpr{exprs}
}

fn parse_row_constructor2(expr QueryExpression) ?Expr {
	return expr
}
