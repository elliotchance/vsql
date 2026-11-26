module vsql

import time

// ISO/IEC 9075-2:2023, 11.32, <view definition>
//
// Define a viewed table.
//
// ISO/IEC 9075-1:2023, 4.8.6, View definitions
//
// A view is stored as the text of its <query expression>, which is planned
// again each time the view is read, as a derived table with the name of the
// view (General Rules, 2.b.iii, see create_view_plan). The names in the query
// are resolved in the schema of the view, both when it's created and when it's
// read, so that a view means the same thing whatever the current schema is.
//
// The columns of a view are fixed when it's created. If a table that the query
// reads with * has columns added later, the view only has the columns that it
// was created with. A view that's simply updatable can be changed (see
// updatable_view). The tables, views and columns that it uses
// (see ViewUsage) can only be dropped with CASCADE, which drops the view too
// (see dependent_views).

const view_file_format_version = u16(5)

// ViewDefinition is a CREATE VIEW. text is its <query expression> as it was
// written, which is how it's stored in the file (see View.bytes).
struct ViewDefinition {
	table_name   Identifier
	columns      []Identifier
	query        QueryExpression
	text         string
	check_option string
}

// ViewCheckOption is the <levels clause> of a WITH CHECK OPTION ("CASCADED" or
// "LOCAL"), and the number of tokens it has.
struct ViewCheckOption {
	level  string
	tokens int
}

// View is a view that has been created.
struct View {
	name    Identifier
	columns []string
	// query is the text of the <query expression>, as it was written.
	query string
	// check_option is "CASCADED" or "LOCAL" for WITH CHECK OPTION, or empty
	// when it's omitted (see check_view_option).
	//
	// ISO/IEC 9075-2:2023, 11.32, <view definition>, General Rules, 1.g
	check_option string
	tid          u64
}

// written_view_query is the text of the <query expression> of the view
// definition that the parser has just read, which starts after the first AS
// after the CREATE (that isn't in the parentheses of the column list), and ends
// before the last trailing tokens (the WITH CHECK OPTION). CREATE and AS are
// reserved words, so CREATE can't be in the query, and AS can't be the name of
// the view or of a column.
fn written_view_query(mut yylex YYLexer, has_lookahead bool, trailing int) string {
	l := yylex as Lexer
	first, last := view_query_tokens(l, has_lookahead, trailing)

	return l.written_text(first, last)
}

// flag_view_check_option flags a view WITH CHECK OPTION whose query contains
// another query, such as a subquery (a SELECT, VALUES or TABLE after the first
// one).
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, Conformance Rules, 4
fn flag_view_check_option(mut yylex YYLexer, has_lookahead bool, trailing int) {
	l := yylex as Lexer
	first, last := view_query_tokens(l, has_lookahead, trailing)
	mut queries := 0
	for token in l.tokens[first..last] {
		if token.token in [token_select, token_values, token_table] {
			queries++
		}
	}
	flag_if(mut yylex, queries > 1, 'F751')
}

// view_query_tokens is the range of tokens of the query, see
// written_view_query.
fn view_query_tokens(l Lexer, has_lookahead bool, trailing int) (int, int) {
	last := l.last_token(has_lookahead) - trailing
	mut first := last
	for l.tokens[first].token != token_create {
		first--
	}

	mut depth := 0
	for {
		first++
		token := l.tokens[first].token
		if token == token_operator_left_paren {
			depth++
		} else if token == token_operator_right_paren {
			depth--
		} else if token == token_as && depth == 0 {
			break
		}
	}

	return first + 1, last
}

fn (stmt ViewDefinition) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	stmt.create(mut conn)!

	return new_result_msg('CREATE VIEW 1', elapsed_parse, t.elapsed())
}

// create creates the view. The caller must have the write connection open.
fn (stmt ViewDefinition) create(mut conn Connection) ! {
	name := conn.resolve_schema_identifier(stmt.table_name)!
	check_writable_schema(name)!
	mut catalog := conn.catalog_for(name)

	// A view has the same names as tables.
	//
	// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 4
	if name.storage_id() in catalog.storage.tables || name.storage_id() in catalog.storage.views
		|| name.storage_id() in catalog.virtual_tables {
		return sqlstate_42p07_table(name) // duplicate table
	}

	// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 2
	for token in tokenize(stmt.text)! {
		if token.token == token_operator_question_mark {
			return sqlstate_42601("a view can't contain a parameter")
		}
	}

	// A top-level ORDER BY, OFFSET and FETCH FIRST (F852, F864 and F859) are
	// planned like they are in a derived table.
	//
	// ISO/IEC 9075-2:2023, 11.32, <view definition>, Conformance Rules, 6 to 8
	subplan := view_query_plan(mut conn, name, stmt.query)!
	query_columns := subplan.columns()

	// A view column list is needed for a column with an implementation-dependent
	// name (such as COL1), or two columns with the same name.
	//
	// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 14 and 24.a
	mut columns := []string{}
	if stmt.columns.len > 0 {
		if stmt.columns.len != query_columns.len {
			return sqlstate_42601('view ${name} has ${stmt.columns.len} columns, but its query has ${query_columns.len}')
		}
		columns = stmt.columns.map(it.sub_entity_name)
	} else {
		for i, column in query_columns {
			if column.unnamed {
				return sqlstate_42601('column ${i + 1} of the query needs a name, or a view column list is needed')
			}
			columns << column.name.sub_entity_name
		}
	}
	for i, column in columns {
		if column in columns[..i] {
			return sqlstate_42601('column ${column} is specified more than once')
		}
	}

	view := View{
		name:         Identifier{
			schema_name: name.schema_name
			entity_name: name.entity_name
		}
		columns:      columns
		query:        stmt.text
		check_option: stmt.check_option
	}

	// A view with CHECK OPTION must be updatable, since the check is made when
	// it's changed. Only a simply updatable view can be changed (without T111),
	// which is what LOCAL needs, and it's also effectively updatable, which is
	// what CASCADED needs.
	//
	// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 17 and 18
	if stmt.check_option != '' {
		conn.updatable_view(view, name.catalog_name, map[string]Value{})!
		conn.check_view_deterministic(view, name)!
	}

	// ISO/IEC 9075-2:2023, 11.32, <view definition>, General Rules, 1
	catalog.storage.create_view(name, view)!
}

fn (stmt ViewDefinition) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE VIEW')
}

// check_view_deterministic returns an error if the query of a view with CHECK
// OPTION contains a potential source of non-determinism, including in a view
// that it reads, so that a row that's seen through the view when it's checked
// is still seen through it later. With LOCAL, the view in its FROM (its leaf
// underlying table) can be non-deterministic, but not a view in a subquery. A
// subquery is planned (and its expressions are compiled) when the tables that
// it reads are collected.
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 20
// ISO/IEC 9075-2:2023, 9.16, Potential sources of non-determinism, Syntax Rules, 1.p
fn (mut conn Connection) check_view_deterministic(view View, name Identifier) ! {
	nondeterministic_not_allowed := conn.nondeterministic_not_allowed
	nondeterministic_leaf_allowed := conn.nondeterministic_leaf_allowed
	conn.nondeterministic_not_allowed = 'a view with CHECK OPTION'
	conn.nondeterministic_leaf_allowed = view.check_option == 'LOCAL'
	defer {
		conn.nondeterministic_not_allowed = nondeterministic_not_allowed
		conn.nondeterministic_leaf_allowed = nondeterministic_leaf_allowed
	}

	query := view.query_expression()!
	view_query_plan(mut conn, name, query)!

	scope := conn.enter_view(name)
	defer {
		conn.leave_view(scope)
	}
	if query.body is QuerySpecification {
		conn.tables_of_subqueries(query.body, map[string]Value{})!
	}
}

// view_query_plan plans the query of the view called name. Its names are
// resolved in the schema of the view, both when it's planned and when it's
// executed (see Plan.execute).
fn view_query_plan(mut conn Connection, name Identifier, query QueryExpression) !Plan {
	scope := conn.enter_view(name)
	defer {
		conn.leave_view(scope)
	}

	mut plan := create_query_expression_plan(query, map[string]Value{}, mut conn, Correlation{})!
	plan.view = PlanView{name, conn}

	return plan
}

// ViewScope is how the connection resolved names before it started on the query
// of a view (see enter_view).
struct ViewScope {
	catalog                string
	schema                 string
	next_value_not_allowed string
	in_derived_table       bool
}

// enter_view resolves the names that follow in the schema of the view called
// name, until leave_view.
fn (mut conn Connection) enter_view(name Identifier) ViewScope {
	scope := ViewScope{conn.current_catalog, conn.current_schema, conn.next_value_not_allowed, conn.in_derived_table}
	conn.current_catalog = if name.catalog_name != '' { name.catalog_name } else { scope.catalog }
	conn.current_schema = name.schema_name
	conn.next_value_not_allowed = 'a view'
	conn.in_derived_table = true

	return scope
}

fn (mut conn Connection) leave_view(scope ViewScope) {
	conn.current_catalog = scope.catalog
	conn.current_schema = scope.schema
	conn.next_value_not_allowed = scope.next_value_not_allowed
	conn.in_derived_table = scope.in_derived_table
}

// view_table is a view as a virtual table, for the INFORMATION_SCHEMA. The
// types of its columns are the types of the columns of its query
// (ISO/IEC 9075-11:2006, 6.20, COLUMNS base table, Description, 1.b), which can
// change when the tables that it reads are changed. A view that can't be read
// (such as when a table that it reads was dropped) has no columns.
fn view_table(mut conn Connection, catalog_name string, view View) Table {
	name := Identifier{
		...view.name
		catalog_name: catalog_name
	}
	mut columns := []Column{}
	// The query was parsed when the view was created, so it always can be.
	if query := view.query_expression() {
		if plan := view_query_plan(mut conn, name, query) {
			query_columns := plan.columns()
			if query_columns.len >= view.columns.len {
				for i, column in view.columns {
					columns << Column{
						...query_columns[i]
						name: Identifier{
							...name
							sub_entity_name: column
						}
					}
				}
			}
		}
	}

	_ := conn.updatable_view(view, catalog_name, map[string]Value{}) or {
		return Table{
			name:       name
			columns:    columns
			is_virtual: true
		}
	}

	return Table{
		name:       name
		columns:    columns
		is_virtual: true
		updatable:  true
	}
}

// find_view returns the view that a table name refers to, if it is one, and the
// name of its catalog.
fn (mut conn Connection) find_view(identifier Identifier) ?(View, string) {
	name := conn.resolve_schema_identifier(identifier) or { return none }
	catalog := conn.catalogs[name.catalog_name] or { return none }
	view := catalog.storage.views[name.storage_id()] or { return none }

	return view, name.catalog_name
}

// create_view_plan reads the rows of a view (the table primary is the name of
// the view), as a derived table with the name of the view, or its correlation
// name. A derived column list renames the columns of the view.
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, General Rules, 2.b.iii
fn create_view_plan(body QuerySpecification, from_clause TablePrimary, view View, params map[string]Value, mut conn Connection, catalog_name string, filter bool) !(Plan, Table) {
	// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 20
	nondeterministic_not_allowed := conn.nondeterministic_not_allowed
	if conn.nondeterministic_leaf_allowed && conn.subquery_scopes.len == 0 {
		conn.nondeterministic_not_allowed = ''
	}
	defer {
		conn.nondeterministic_not_allowed = nondeterministic_not_allowed
	}

	mut query := view.query_expression()!
	if conn.without_view_where && query.body is QuerySpecification {
		spec := query.body as QuerySpecification
		query = QueryExpression{
			...query
			body: QuerySpecification{
				...spec
				table_expression: &TableExpression{
					...spec.table_expression
					where_clause: none
				}
			}
		}
	}
	name := Identifier{
		...view.name
		catalog_name: catalog_name
	}
	// What the view's query uses isn't used by the query that reads the view.
	usage := conn.view_usage
	conn.view_usage = unsafe { nil }
	subplan := view_query_plan(mut conn, name, query) or {
		conn.view_usage = usage
		return err
	}
	conn.view_usage = usage

	// A column that the query no longer has (such as a column of a table that
	// was dropped) is an error, but extra columns (a table read with * that
	// has more columns) are left out, see add_correlation_plan.
	if subplan.columns().len < view.columns.len {
		return sqlstate_42601('view ${name} has ${view.columns.len} columns, but its query has ${subplan.columns().len}')
	}

	mut correlation := Correlation{
		name:    view.name
		columns: view.columns.map(Identifier{
			sub_entity_name: it
		})
		degree:  view.columns.len
	}
	if from_clause.correlation.name.sub_entity_name != '' {
		correlation = Correlation{
			...correlation
			name: from_clause.correlation.name
		}
	}
	if from_clause.correlation.columns.len > 0 {
		correlation = Correlation{
			...correlation
			columns: from_clause.correlation.columns
		}
	}

	mut plan := Plan{}
	table := add_correlation_plan(mut &plan, correlation.name, subplan, correlation,
		params, mut conn)!
	if !isnil(conn.view_usage) {
		conn.view_usage.add_correlation(table, view.name, view.columns)
	}

	if filter {
		add_where_plan(mut &plan, body, params, conn, {
			table.name.id(): &Table{
				...table
			}
		}, [])!
	}

	return plan, table
}

// bytes is the definition of the view in the file, see "View Object" in the
// "File Format" docs. Every name is delimited, but the query is kept exactly as
// it was written.
fn (v View) bytes() []u8 {
	columns := v.columns.map(delimit_identifier(it)).join(', ')

	check_option := match v.check_option {
		'' { '' }
		'CASCADED' { ' WITH CHECK OPTION' }
		else { ' WITH ${v.check_option} CHECK OPTION' }
	}

	return 'CREATE VIEW ${v.name.storage_sql()} (${columns}) AS ${v.query}${check_option}'.bytes()
}

// query_expression parses the query of the view again.
fn (v View) query_expression() !QueryExpression {
	stmt := parse_definition(v.bytes())!

	return (stmt as ViewDefinition).query
}

// new_view_from_bytes reads a View Object, which is only ever a CREATE VIEW.
fn new_view_from_bytes(data []u8, tid u64) !View {
	stmt := parse_definition(data)! as ViewDefinition

	return View{
		name:         Identifier{
			schema_name: stmt.table_name.schema_name
			entity_name: stmt.table_name.entity_name
		}
		columns:      stmt.columns.map(it.sub_entity_name)
		query:        stmt.text
		check_option: stmt.check_option
		tid:          tid
	}
}

fn view_object_key(name Identifier) []u8 {
	return 'W${name.storage_id()}'.bytes()
}

// create_view stores the view. name is its full name, including the catalog.
fn (mut f Storage) create_view(name Identifier, view View) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_name(`T`, name)!
	f.check_concurrent_name(`W`, name)!

	// Older versions of vsql don't know about views, so they could create a
	// table with the same name.
	if f.header.write_version < view_file_format_version {
		f.header.write_version = view_file_format_version
	}

	stored := View{
		...view
		tid: f.transaction_id
	}
	f.btree.add(new_page_object(view_object_key(view.name), f.transaction_id, 0, stored.bytes()))!

	f.save_schema()
	f.views[view.name.storage_id()] = stored
	f.schema_changed()!
}

fn (mut f Storage) delete_view(view View) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.btree.expire(view_object_key(view.name), view.tid, f.transaction_id)!

	f.save_schema()
	f.views.delete(view.name.storage_id())
	f.schema_changed()!
}

// load_views reads the views that are visible to the current transaction, see
// load_schema.
fn (mut f Storage) load_views() ! {
	f.views = map[string]View{}
	mut iter := f.btree.new_range_iterator('W'.bytes(), 'X'.bytes())
	for {
		object := iter.next() or { break }
		if f.is_visible(object.tid, object.xid) {
			view := new_view_from_bytes(object.value, object.tid)!
			f.views[view.name.storage_id()] = view
		}
	}
	if err := iter.err {
		return err
	}
}

// RecursiveViewHead is a CREATE RECURSIVE VIEW before its query, see
// recursive_view_definition.
struct RecursiveViewHead {
	table_name Identifier
	columns    []Identifier
	query      RecursiveQueryReference
}

// recursive_view_head puts the name of a RECURSIVE view in scope for its query,
// like the name of a WITH RECURSIVE query. It must have a view column list.
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 9.a
// ISO/IEC 9075-2:2023, 11.32, <view definition>, Conformance Rules, 1
fn recursive_view_head(mut yylex YYLexer, table_name Identifier, columns []Identifier) !RecursiveViewHead {
	if columns.len == 0 {
		return sqlstate_42601('RECURSIVE view ${table_name} needs a column list')
	}
	flag(mut yylex, 'T131')
	start_recursive_with(mut yylex, false)!

	return RecursiveViewHead{
		table_name: table_name
		columns:    columns
		query:      RecursiveQueryReference{
			query: add_recursive_query_name(mut yylex, Identifier{
				sub_entity_name: table_name.entity_name
			})!
		}
	}
}

// recursive_view_definition is a CREATE RECURSIVE VIEW, which is the same as a
// view of a WITH RECURSIVE query with the same name and columns. That's also how
// it's kept.
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 9, 9.b and 9.e
fn recursive_view_definition(mut yylex YYLexer, head RecursiveViewHead, query QueryExpression, has_lookahead bool) !ViewDefinition {
	mut recursive_query := head.query.query
	element := recursive_with_list_element(mut yylex, mut recursive_query, head.columns,
		TablePrimary{
			body: query
		})!
	finish_recursive_with([element])

	name := head.table_name.entity_name
	table_expression := TableExpression{TableReference(table_or_query_name_primary(mut yylex,
		Identifier{ entity_name: name }, Correlation{})), none, []Identifier{}, none}
	with_query := with_query_expression(mut yylex, [element], QueryExpression{
		body: SimpleTable(QuerySpecification{
			exprs:            SelectList(AsteriskExpr(true))
			table_expression: &table_expression
		})
	})

	columns := head.columns.map(requote_identifier(it.sub_entity_name)).join(', ')
	text := written_view_query(mut yylex, has_lookahead, 0)

	return ViewDefinition{
		table_name: head.table_name
		columns:    head.columns
		query:      with_query
		text:       'WITH RECURSIVE ${requote_identifier(name)} (${columns}) AS (${text}) SELECT * FROM ${requote_identifier(name)}'
	}
}
