module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.32, <view definition>
//
// Define a viewed table.
//
// The concept is described by:
//
// ISO/IEC 9075-1:2003(E), 4.6.7, View definitions

// view_file_format_version is the version of the file format that the first
// view raises the Write Version of the file to. An older version of vsql
// ignores the View Objects, so it can still read the file, but it would let a
// table that a view depends on be dropped (or a table be created with the name
// of a view). See "Compatibility" in the "File Format" docs.
const view_file_format_version = u16(4)

// ViewDefinition is CREATE VIEW. It's also how a view is stored in the file
// (see View.definition_bytes), where the <view column list> is always given and
// the query has no asterisks (see expand_asterisks).
struct ViewDefinition {
	view_name Identifier
	// columns is the <view column list>, which is empty when it isn't given.
	columns []Identifier
	query   QueryExpression
	// has_parameters is true when the statement contains a <dynamic parameter
	// specification> or a <host parameter specification>, which can only be in
	// the query.
	has_parameters bool
}

// A View is the descriptor of a viewed table. Its rows are the result of its
// query, which is planned (like a derived table) every time the view is read,
// see Connection.view_plan.
struct View {
	// tid is the transaction ID that created this view.
	tid u64
	// name includes the catalog and schema.
	name Identifier
	// columns are the names of the columns of the view, in order.
	columns []string
	// query is the original <query expression>, with each asterisk replaced by
	// the columns it was when the view was created.
	query QueryExpression
	// schema is the implicit schema of the names in the query, which is the
	// default schema of the SQL-session (or of the CREATE SCHEMA) when the view
	// was created (ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Syntax
	// Rules, 4). It's always in the catalog of the view.
	schema string
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
	// ISO/IEC 9075-2:2016(E), 11.32, <view definition>, Syntax Rules, 2
	if stmt.has_parameters {
		return sqlstate_42601('a view cannot contain parameters')
	}

	view_name := conn.resolve_schema_identifier(stmt.view_name)!
	check_writable_schema(view_name)!
	mut catalog := conn.catalog_for(view_name)

	// A view is a table, so it can't have the same name as any other table,
	// including a virtual table (which would hide it).
	//
	// ISO/IEC 9075-2:2016(E), 11.32, <view definition>, Syntax Rules, 4
	id := view_name.storage_id()
	if id in catalog.storage.tables || id in catalog.storage.views || id in catalog.virtual_tables {
		return sqlstate_42p07('table', view_name.str()) // duplicate table
	}

	// The query is planned the same way that it will be when the view is read,
	// which also checks it. It can only read views that already exist, so two
	// views can't read each other, and a view can't read itself (RECURSIVE isn't
	// supported).
	//
	// ISO/IEC 9075-2:2016(E), 11.32, <view definition>, Syntax Rules, 5 and 8
	mut view := View{
		name:   view_name
		query:  stmt.query
		schema: conn.current_schema
	}
	view = View{
		...view
		query: conn.expand_asterisks(view, stmt.query)!
	}
	columns := conn.view_plan(view)!.columns()

	// ISO/IEC 9075-2:2016(E), 11.32, <view definition>, Syntax Rules, 14 and 22.a
	mut names := []string{}
	if stmt.columns.len > 0 {
		if stmt.columns.len != columns.len {
			return sqlstate_42601('view ${view_name} has ${stmt.columns.len} ${pluralize(stmt.columns.len, 'column')}, but its query has ${columns.len}')
		}
		names = stmt.columns.map(it.sub_entity_name)
	} else {
		for column in columns {
			if column.unnamed {
				return sqlstate_42601('view ${view_name} needs a column list because column ${names.len + 1} of its query has no name')
			}
			names << column.name.sub_entity_name
		}
	}
	mut seen := map[string]bool{}
	for name in names {
		if name in seen {
			return sqlstate_42601('column ${requote_identifier(name)} is specified more than once in view ${view_name}')
		}
		seen[name] = true
	}

	// ISO/IEC 9075-2:2016(E), 11.32, <view definition>, General Rules, 1
	catalog.storage.create_view(View{
		...view
		columns: names
	})!
}

// definition is the CREATE VIEW of a view, without the catalog (just like a
// table), so the file can be attached with any catalog name.
fn (v View) definition() string {
	return 'CREATE VIEW ${v.name.storage_sql()} (${v.columns.map(delimit_identifier(it)).join(', ')}) AS ${v.query.pstr(map[string]Value{})}'
}

// set_schema is the SET SCHEMA that makes the implicit schema of the names in
// the query of a view the current schema.
fn (v View) set_schema() string {
	return 'SET SCHEMA ${new_varchar_value(v.schema).literal()}'
}

// definition_bytes is what's stored in the file for a view (see "View Object"
// in the "File Format" docs): the SET SCHEMA of its implicit schema, then its
// CREATE VIEW.
fn (v View) definition_bytes() []u8 {
	return '${v.set_schema()}; ${v.definition()}'.bytes()
}

// new_view_from_bytes reads a view that was stored by definition_bytes.
fn new_view_from_bytes(data []u8, tid u64, catalog_name string) !View {
	statements := split_statements(data.bytestr())
	set_schema := parse_definition(statements[0].bytes())!
	stmt := parse_definition((statements[1] or { '' }).bytes())!
	if set_schema is SetSchemaStatement && stmt is ViewDefinition {
		return View{
			tid:     tid
			name:    Identifier{
				catalog_name: catalog_name
				schema_name:  stmt.view_name.schema_name
				entity_name:  stmt.view_name.entity_name
			}
			columns: stmt.columns.map(it.sub_entity_name)
			query:   stmt.query
			schema:  (set_schema.schema_name as Value).string_value()
		}
	}

	return sqlstate_xx001('not a view definition: ${data.bytestr()}')
}

// view_plan plans the query of a view, which is how a view is read. It's
// planned like a derived table (General Rules, 2.b.iii), except that:
//
// - The names in the query are resolved in the schema that was the current
//   schema when the view was created (View.schema), rather than the current
//   schema now, so that the view is the same however it's read.
//
// - It can only use the tables of its own catalog, since the name of another
//   catalog isn't part of the file.
//
// - The features that the query uses aren't flagged, because they aren't part
//   of the statement that reads the view (the tables it reads are, see
//   Connection.flag_self_reference).
//
// - A NEXT VALUE FOR can't be used (ISO/IEC 9075-2:2016(E), 6.14, <next value
//   expression>, Syntax Rules, 1).
//
// The expressions of the plan are compiled again when it runs, so it's wrapped
// in a ViewScopeOperation that resolves the names the same way then.
//
// ISO/IEC 9075-2:2016(E), 11.32, <view definition>, General Rules, 2.b.iii
fn (mut conn Connection) view_plan(view View) !Plan {
	scope := conn.enter_view_scope(view)
	defer {
		conn.leave_view_scope(scope)
	}
	flagged_features := conn.flagged_features.clone()
	defer {
		conn.flagged_features = flagged_features
	}
	next_value_not_allowed := conn.next_value_not_allowed
	conn.next_value_not_allowed = 'a view'
	defer {
		conn.next_value_not_allowed = next_value_not_allowed
	}
	in_derived_table := conn.in_derived_table
	conn.in_derived_table = true
	defer {
		conn.in_derived_table = in_derived_table
	}

	plan := create_query_expression_plan(view.query, map[string]Value{}, mut conn,
		Correlation{})!

	return Plan{
		operations: [
			PlanOperation(&ViewScopeOperation{
				view: view
				plan: plan
				conn: conn
			}),
		]
	}
}

// ViewScope is what Connection.enter_view_scope changes, so that it can be put
// back.
struct ViewScope {
	current_catalog string
	current_schema  string
	view_catalog    string
	subquery_scopes []SubqueryScope
}

// enter_view_scope makes the implicit schema of the view the current schema
// (see View.schema), and stops
// the query of a view from seeing the columns of the query that reads it (a
// view can't be correlated).
fn (mut conn Connection) enter_view_scope(view View) ViewScope {
	scope := ViewScope{
		current_catalog: conn.current_catalog
		current_schema:  conn.current_schema
		view_catalog:    conn.view_catalog
		subquery_scopes: conn.subquery_scopes
	}
	conn.current_catalog = view.name.catalog_name
	conn.current_schema = view.schema
	conn.view_catalog = view.name.catalog_name
	conn.subquery_scopes = []

	return scope
}

fn (mut conn Connection) leave_view_scope(scope ViewScope) {
	conn.current_catalog = scope.current_catalog
	conn.current_schema = scope.current_schema
	conn.view_catalog = scope.view_catalog
	conn.subquery_scopes = scope.subquery_scopes
}

// A ViewScopeOperation runs the plan of a view (see Connection.view_plan) with
// the names resolved in the implicit schema of the view.
struct ViewScopeOperation {
	view View
mut:
	plan Plan
	conn &Connection
}

fn (o &ViewScopeOperation) str() string {
	return 'VIEW ${o.view.name}'
}

fn (o &ViewScopeOperation) columns() Columns {
	return o.plan.columns()
}

fn (mut o ViewScopeOperation) execute(rows []Row) ![]Row {
	scope := o.conn.enter_view_scope(o.view)
	defer {
		o.conn.leave_view_scope(scope)
	}

	return o.plan.execute(rows)!
}

// expand_asterisks replaces each asterisk (and qualified asterisk) in the select
// list of the query of a view with the columns that it is now. A column that's
// added to a table later isn't a column of the view. Only the queries that make
// the rows of the view are changed, not a subquery.
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 4 and 5
fn (mut conn Connection) expand_asterisks(view View, query QueryExpression) !QueryExpression {
	scope := conn.enter_view_scope(view)
	defer {
		conn.leave_view_scope(scope)
	}

	return QueryExpression{
		...query
		body: conn.expand_simple_table_asterisks(view, query.body)!
	}
}

fn (mut conn Connection) expand_simple_table_asterisks(view View, body SimpleTable) !SimpleTable {
	match body {
		QuerySpecification {
			return SimpleTable(conn.expand_query_specification_asterisks(view, body)!)
		}
		[]RowValueConstructor {
			return body
		}
		SetOperation {
			return SimpleTable(SetOperation{
				...body
				left:  &QueryExpression{
					...*body.left
					body: conn.expand_simple_table_asterisks(view, body.left.body)!
				}
				right: &QueryExpression{
					...*body.right
					body: conn.expand_simple_table_asterisks(view, body.right.body)!
				}
			})
		}
		ParenthesizedQueryExpression {
			return SimpleTable(ParenthesizedQueryExpression{&QueryExpression{
				...*body.expr
				body: conn.expand_simple_table_asterisks(view, body.expr.body)!
			}})
		}
	}
}

fn (mut conn Connection) expand_query_specification_asterisks(view View, body QuerySpecification) !QuerySpecification {
	has_asterisk := match body.exprs {
		AsteriskExpr { true }
		[]SelectSublist { body.exprs.any(it is QualifiedAsteriskExpr) }
	}
	if !has_asterisk {
		return body
	}

	_, tables := create_select_plan(body, map[string]Value{}, mut conn, true)!
	mut exprs := []SelectSublist{}
	match body.exprs {
		AsteriskExpr {
			for _, table in tables {
				exprs << asterisk_columns(view, table)
			}
		}
		[]SelectSublist {
			for item in body.exprs {
				match item {
					DerivedColumn {
						exprs << item
					}
					QualifiedAsteriskExpr {
						exprs << asterisk_columns(view, qualified_asterisk_table(item, mut conn,
							tables)!)
					}
				}
			}
		}
	}

	return QuerySpecification{
		...body
		exprs: SelectList(exprs)
	}
}

// asterisk_columns are the columns of a range variable that an asterisk expands
// to, as column references that can be written in the definition of a view.
// The catalog isn't part of the name, since it's resolved in the catalog of the
// view, and neither is the schema if it's the implicit schema of the names in
// the view (see View.schema). The common
// columns of a <joined table> can only be referenced by their unqualified names.
fn asterisk_columns(view View, table Table) []SelectSublist {
	mut exprs := []SelectSublist{}
	for column in table.columns {
		name := column.name.sub_entity_name
		reference := if table.name.custom_id != '' {
			Identifier{
				sub_entity_name: name
			}
		} else if table.name.entity_name != '' {
			Identifier{
				schema_name:     if table.name.schema_name == view.schema {
					''
				} else {
					table.name.schema_name
				}
				entity_name:     table.name.entity_name
				sub_entity_name: name
			}
		} else {
			Identifier{
				entity_name:     table.name.id()
				sub_entity_name: name
			}
		}
		exprs << SelectSublist(column_derived_column(Column{
			name: reference
		}))
	}

	return exprs
}

fn (stmt ViewDefinition) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE VIEW')
}

// is_view is true if the name (which doesn't need to be resolved) is a view.
fn (mut conn Connection) is_view(name Identifier) bool {
	ident := conn.resolve_identifier(name)
	catalog := conn.catalogs[ident.catalog_name] or { return false }

	return ident.storage_id() in catalog.storage.views
}

// view_table is the table of a view, with the columns that its query has now.
fn (mut conn Connection) view_table(view View) !Table {
	plan := conn.view_plan(view)!
	mut columns := []Column{}
	for i, column in plan.columns() {
		columns << Column{
			name:     Identifier{
				...view.name
				sub_entity_name: view.columns[i] or { column.name.sub_entity_name }
			}
			typ:      column.typ
			not_null: column.not_null
		}
	}

	return Table{
		name:       view.name
		columns:    columns
		is_virtual: true
	}
}

// drop_dependent_views drops each view of the catalog that can't be read any
// more, or that would have different columns, after a table, view or column
// that it depends on was removed (which is done first, by the same statement).
// With RESTRICT, it's an error instead. Every view is planned again, because
// that's the only way to know what a view depends on. A view that depends on
// another view that's dropped is also dropped, since it can't be read either.
//
// object_name is what was removed, for the error. With CASCADE, the standard
// drops the views by revoking the privileges on what was removed (there are no
// privileges, #732), so they're dropped here instead.
//
// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>, Syntax Rules, 7.a
// ISO/IEC 9075-2:2016(E), 11.33, <drop view statement>, Syntax Rules, 5.a
// ISO/IEC 9075-2:2016(E), 11.23, <drop column definition>, Syntax Rules, 7.a
// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>, General Rules, 2
fn (mut conn Connection) drop_dependent_views(mut catalog CatalogConnection, behavior string, object_name string, before map[string][]Column) ! {
	if catalog.storage.views.len == 0 {
		return
	}

	// Planning a view can add warnings, which aren't part of this statement.
	warnings := conn.warnings.clone()
	defer {
		conn.warnings = warnings
	}

	// The views are sorted so that the same error is always returned, and
	// they're always dropped in the same order.
	mut ids := catalog.storage.views.keys()
	ids.sort()
	mut dependent := []View{}
	for id in ids {
		view := catalog.storage.views[id] or { continue }
		table := conn.view_table(view) or {
			dependent << view
			continue
		}
		if old_columns := before[id] {
			if table.columns.map('${it.name.sub_entity_name} ${it.typ}') != old_columns.map('${it.name.sub_entity_name} ${it.typ}') {
				dependent << view
			}
		}
	}

	if dependent.len > 0 && behavior == 'RESTRICT' {
		return sqlstate_2bp01('${object_name} (view ${dependent[0].name} depends on it)')
	}

	for view in dependent {
		catalog.storage.delete_view(view)!
	}
}

// view_columns are the columns of each view of the catalog, keyed by the
// storage_id of the view, so that drop_dependent_views can find the views that
// a change to a table would change.
fn (mut conn Connection) view_columns(catalog &CatalogConnection) map[string][]Column {
	mut columns := map[string][]Column{}
	for id, view in catalog.storage.views {
		table := conn.view_table(view) or { continue }
		columns[id] = table.columns
	}

	return columns
}

// view_catalog_check returns an error when the query of a view (see
// Connection.view_plan) reads a table of another catalog.
fn (conn &Connection) view_catalog_check(table_name Identifier) ! {
	if conn.view_catalog != '' && table_name.catalog_name != conn.view_catalog {
		return sqlstate_42601('a view cannot read ${table_name} because it is in another catalog')
	}
}

// create_view stores a new view.
fn (mut f Storage) create_view(view View) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// Another transaction can't be creating or dropping a table or view with
	// the same name, or changing a table (or view) that this view may read.
	f.check_concurrent_objects('T'.bytes(), 'U'.bytes())!
	f.check_concurrent_objects('W'.bytes(), 'X'.bytes())!

	// The Write Version is never lowered, even when the last view is dropped.
	if f.header.write_version < view_file_format_version {
		f.header.write_version = view_file_format_version
	}

	new_view := View{
		...view
		tid: f.transaction_id
	}
	f.btree.add(new_page_object(view_object_key(view.name), f.transaction_id, 0, new_view.definition_bytes()))!

	f.save_schema()
	f.views[view.name.storage_id()] = new_view
	f.schema_changed()
}

// delete_view expires a view.
fn (mut f Storage) delete_view(view View) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// Another transaction can't be creating a view that reads this one.
	f.check_concurrent_objects('W'.bytes(), 'X'.bytes())!

	f.btree.expire(view_object_key(view.name), view.tid, f.transaction_id)!

	f.save_schema()
	f.views.delete(view.name.storage_id())
	f.schema_changed()
}

// load_views reads the views that are visible to the current transaction.
fn (mut f Storage) load_views(catalog_name string) ! {
	f.save_schema()
	f.views = map[string]View{}
	for object in f.read_objects('W'.bytes(), 'X'.bytes())! {
		view := new_view_from_bytes(object.value, object.tid, catalog_name)!
		f.views[view.name.storage_id()] = view
	}
}

// view_object_key is the key of the View Object of a view, see "File Format" in
// the docs.
fn view_object_key(name Identifier) []u8 {
	return 'W${name.storage_id()}'.bytes()
}
