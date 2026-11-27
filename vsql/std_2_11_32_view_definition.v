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
// was created with. A view can't be changed (INSERT, UPDATE and DELETE on a
// view are an error, see #1448). The tables, views and columns that it uses
// (see ViewUsage) can only be dropped with CASCADE, which drops the view too
// (see dependent_views).

const view_file_format_version = u16(5)

// ViewDefinition is a CREATE VIEW. text is its <query expression> as it was
// written, which is how it's stored in the file (see View.bytes).
struct ViewDefinition {
	table_name Identifier
	columns    []Identifier
	query      QueryExpression
	text       string
}

// View is a view that has been created.
struct View {
	name    Identifier
	columns []string
	// query is the text of the <query expression>, as it was written.
	query string
	tid   u64
}

// written_view_query is the text of the <query expression> of the view
// definition that the parser has just read, which starts after the first AS
// after the CREATE (that isn't in the parentheses of the column list). CREATE
// and AS are reserved words, so CREATE can't be in the query, and AS can't be
// the name of the view or of a column.
fn written_view_query(mut yylex YYLexer, has_lookahead bool) string {
	l := yylex as Lexer
	last := l.last_token(has_lookahead)
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

	return l.written_text(first + 1, last)
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

	// A column with a name that vsql made up (such as COL1) doesn't need a view
	// column list (#1770).
	//
	// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 14 and 24.a
	mut columns := []string{}
	if stmt.columns.len > 0 {
		if stmt.columns.len != query_columns.len {
			return sqlstate_42601('view ${name} has ${stmt.columns.len} columns, but its query has ${query_columns.len}')
		}
		columns = stmt.columns.map(it.sub_entity_name)
	} else {
		columns = query_columns.map(it.name.sub_entity_name)
	}
	for i, column in columns {
		if column in columns[..i] {
			return sqlstate_42601('column ${column} is specified more than once')
		}
	}

	// ISO/IEC 9075-2:2023, 11.32, <view definition>, General Rules, 1
	catalog.storage.create_view(name, View{
		name:    Identifier{
			schema_name: name.schema_name
			entity_name: name.entity_name
		}
		columns: columns
		query:   stmt.text
	})!
}

fn (stmt ViewDefinition) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE VIEW')
}

// view_query_plan plans the query of the view called name. Its names are
// resolved in the schema of the view.
fn view_query_plan(mut conn Connection, name Identifier, query QueryExpression) !Plan {
	current_catalog := conn.current_catalog
	current_schema := conn.current_schema
	next_value_not_allowed := conn.next_value_not_allowed
	in_derived_table := conn.in_derived_table
	conn.current_catalog = if name.catalog_name != '' { name.catalog_name } else { current_catalog }
	conn.current_schema = name.schema_name
	conn.next_value_not_allowed = 'a view'
	conn.in_derived_table = true
	defer {
		conn.current_catalog = current_catalog
		conn.current_schema = current_schema
		conn.next_value_not_allowed = next_value_not_allowed
		conn.in_derived_table = in_derived_table
	}

	return create_query_expression_plan(query, map[string]Value{}, mut conn, Correlation{})
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

	return Table{
		name:       name
		columns:    columns
		is_virtual: true
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
	query := view.query_expression()!
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

	return 'CREATE VIEW ${v.name.storage_sql()} (${columns}) AS ${v.query}'.bytes()
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
		name:    Identifier{
			schema_name: stmt.table_name.schema_name
			entity_name: stmt.table_name.entity_name
		}
		columns: stmt.columns.map(it.sub_entity_name)
		query:   stmt.text
		tid:     tid
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
