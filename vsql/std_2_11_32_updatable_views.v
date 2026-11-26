module vsql

// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 10 to 13
//
// A view can be changed by INSERT, UPDATE and DELETE when its query is simply
// updatable, which is when it reads the rows of one table (a base table or
// another view that can be changed), and each column of the view is a different
// column of that table (see updatable_view). Without Feature T111, a view that
// is simply updatable is also generally and effectively updatable, and
// insertable-into.
//
// ISO/IEC 9075-2:2023, 4.17.6, Table updatability
// ISO/IEC 9075-2:2023, 7.6, <table reference>, Syntax Rules, 22.b
//
// A change to the view is a change to the base table that it reads in the end
// (its leaf underlying table):
//
// ISO/IEC 9075-2:2023, 15.9, Effect of deleting some rows from a derived table
// ISO/IEC 9075-2:2023, 15.10, Effect of deleting some rows from a viewed table
// ISO/IEC 9075-2:2023, 15.12, Effect of inserting a table into a derived table
// ISO/IEC 9075-2:2023, 15.13, Effect of inserting a table into a viewed table
// ISO/IEC 9075-2:2023, 15.15, Effect of replacing some rows in a derived table
// ISO/IEC 9075-2:2023, 15.16, Effect of replacing some rows in a viewed table
//
// INSERT puts the new rows in the base table, and its other columns get their
// default (see InsertStatement.insert). A DEFAULT in an INSERT or UPDATE of the
// view is the default of the column of the base table:
//
// ISO/IEC 9075-2:2023, 11.5, <default clause>, General Rules, 3.d
//
// A new row doesn't have to satisfy the
// WHERE of the view, so it may not be seen through the view, unless the view
// has a CHECK OPTION (see check_view_option). UPDATE and DELETE only change
// the rows that are seen through the view. Each row that's read through the
// view keeps the id of its row in the base table (see ExprOperation.execute),
// which is how the row of the base table is found (see base_rows).

// UpdatableView is a view that can be changed. table is its leaf underlying
// table, and columns is the column of table for each column of the view.
// checked_views are the full names of the view and the views it reads that
// have a CHECK OPTION, outermost first (see check_view_option).
struct UpdatableView {
	view          View
	table         Identifier
	columns       map[string]string
	checked_views []Identifier
}

// updatable_view returns the view if it's simply updatable, otherwise it's an
// error. catalog_name is the catalog of the view.
fn (mut conn Connection) updatable_view(view View, catalog_name string, params map[string]Value) !UpdatableView {
	name := Identifier{
		...view.name
		catalog_name: catalog_name
	}

	// The names in the query are resolved in the schema of the view.
	scope := conn.enter_view(name)
	defer {
		conn.leave_view(scope)
	}

	updatable, ok := conn.updatable_query(view.query_expression()!, view.columns, params)!
	if !ok {
		return sqlstate_42601('view ${name} is not updatable')
	}
	mut checked_views := if view.check_option != '' { [name] } else { []Identifier{} }
	checked_views << updatable.checked_views

	return UpdatableView{view, updatable.table, updatable.columns, checked_views}
}

// updatable_query returns the leaf underlying table of query, and the column of
// that table for each of column_names (the names of the columns of query), when
// query is simply updatable. Otherwise, it returns false.
//
// ISO/IEC 9075-2:2023, 7.16, <query specification>, Syntax Rules, 22 to 29
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 7, 9 and 11
//
// The FROM can also be a derived table (or a WITH query name, which is read as
// a derived table, see Lexer.with_scopes) whose query is simply updatable, and
// then its leaf underlying table is the leaf underlying table of query.
//
// ISO/IEC 9075-2:2023, 7.6, <table reference>, Syntax Rules, 21.b and 22.c
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 10 and 12
fn (mut conn Connection) updatable_query(query QueryExpression, column_names []string, params map[string]Value) !(UpdatableView, bool) {
	body := query.body
	if body !is QuerySpecification || query.offset != none || query.fetch != none {
		return UpdatableView{}, false
	}
	spec := body as QuerySpecification
	from_clause := spec.table_expression.from_clause
	if from_clause !is TablePrimary {
		return UpdatableView{}, false
	}
	table_primary := from_clause as TablePrimary
	if table_primary.body is RecursiveQueryReference || !spec.has_only_distinct_columns() {
		return UpdatableView{}, false
	}

	plan := create_query_expression_plan(query, params, mut conn, Correlation{})!
	for operation in plan.operations {
		if operation is GroupOperation || operation is DistinctOperation
			|| operation is VirtualTableOperation {
			return UpdatableView{}, false
		}
	}

	// The columns of the table that the query reads, and the column of the base
	// table that each one is.
	mut table := Identifier{}
	mut from_columns := []string{}
	mut base_columns := map[string]string{}
	mut checked_views := []Identifier{}
	match table_primary.body {
		Identifier {
			if inner, inner_catalog := conn.find_view(table_primary.body) {
				updatable := conn.updatable_view(inner, inner_catalog, params) or {
					return UpdatableView{}, false
				}
				table = updatable.table
				from_columns = inner.columns
				base_columns = updatable.columns.clone()
				checked_views << updatable.checked_views
			} else {
				// The query was planned, so the table exists.
				table = conn.resolve_table_identifier(table_primary.body, false)!
				for column in conn.catalog_for(table).storage.table(table.storage_id()).columns {
					from_columns << column.name.sub_entity_name
					base_columns[column.name.sub_entity_name] = column.name.sub_entity_name
				}
			}
		}
		QueryExpression {
			derived := table_primary.body
			from_columns = create_query_expression_plan(derived, params, mut conn, Correlation{})!.columns().map(it.name.sub_entity_name)
			updatable, ok := conn.updatable_query(derived, from_columns, params)!
			if !ok {
				return UpdatableView{}, false
			}
			table = updatable.table
			base_columns = updatable.columns.clone()
			checked_views << updatable.checked_views
		}
		RecursiveQueryReference {}
	}

	// A derived column list renames the columns.
	correlation_columns := table_primary.correlation.columns
	if correlation_columns.len > 0 {
		mut renamed := map[string]string{}
		for i, column in correlation_columns {
			renamed[column.sub_entity_name] = base_columns[from_columns[i]]
		}
		from_columns = correlation_columns.map(it.sub_entity_name)
		base_columns = renamed.clone()
	}

	// A subquery in the WHERE can't read the base table.
	if spec.table_expression.where_clause != none
		&& table.id() in conn.tables_of_subqueries(spec, params)! {
		return UpdatableView{}, false
	}

	// Each column of the query is a column of the table, in the order of the
	// table for an asterisk.
	mut columns := map[string]string{}
	for i, column in column_names {
		mut from_column := from_columns[i]
		if spec.exprs is []SelectSublist {
			item := spec.exprs[i] or { spec.exprs[0] }
			if item is DerivedColumn {
				from_column = (item.column_reference() or { return UpdatableView{}, false }).sub_entity_name
			}
		}
		columns[column] = base_columns[from_column]
	}

	return UpdatableView{
		table:         table
		columns:       columns
		checked_views: checked_views
	}, true
}

// view_target is the view that an INSERT, UPDATE or DELETE changes, or none
// when name is a table.
fn (mut conn Connection) view_target(name Identifier, params map[string]Value) !(UpdatableView, bool) {
	view, catalog_name := conn.find_view(name) or { return UpdatableView{}, false }

	return conn.updatable_view(view, catalog_name, params)!, true
}

// resolve_target_identifier is the full name of the table or view that an
// INSERT, UPDATE or DELETE changes.
fn (mut conn Connection) resolve_target_identifier(name Identifier) !Identifier {
	if _, catalog_name := conn.find_view(name) {
		return Identifier{
			...conn.resolve_schema_identifier(name)!
			catalog_name: catalog_name
		}
	}

	return conn.resolve_table_identifier(name, false)
}

// base_column is the column of the base table for a column of the view.
fn (v UpdatableView) base_column(column_name string) !string {
	return v.columns[column_name] or {
		return sqlstate_42703(v.view.name, column_name) // column does not exist
	}
}

// base_rows returns the row of the base table that each row read through the
// view came from.
fn (mut conn Connection) base_rows(target UpdatableView, rows []Row) ![]Row {
	if rows.len == 0 {
		return []Row{}
	}

	mut by_id := map[string]Row{}
	for row in conn.catalog_for(target.table).storage.read_rows(target.table)! {
		by_id[row.id.hex()] = row
	}

	mut base_rows := []Row{cap: rows.len}
	for row in rows {
		base_rows << by_id[row.id.hex()] or { return error('row of view ${target.view.name} not found') }
	}

	return base_rows
}
