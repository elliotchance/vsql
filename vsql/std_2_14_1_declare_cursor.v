module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.1, <declare cursor>
//
// Declare a standing cursor.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.38, Cursors

// A <declare cursor> can only be contained in an SQL-client module, so declaring
// a cursor by executing it is a vsql extension (V108-01). The cursor belongs to
// the connection (the SQL-session) until the connection is closed.
struct DeclareCursor {
	name         string
	hold         bool
	scroll       bool
	query        QueryExpression
	updatability ?UpdatabilityClause
}

// CursorProperties are the <cursor properties> of a DECLARE CURSOR. A cursor is
// NO SCROLL and WITHOUT HOLD unless it says otherwise. scrollability is true
// if SCROLL or NO SCROLL is specified.
//
// ISO/IEC 9075-2:2016(E), 14.2, <cursor properties>, Syntax Rules, 2 and 3
// ISO/IEC 9075-2:2016(E), 14.2, <cursor properties>, General Rules, 1.b and 1.c
struct CursorProperties {
	scroll        bool
	scrollability bool
	hold          bool
}

fn new_declare_cursor(name string, properties CursorProperties, query QueryExpression, updatability ?UpdatabilityClause) DeclareCursor {
	return DeclareCursor{
		name:         name
		hold:         properties.hold
		scroll:       properties.scroll
		query:        query
		updatability: updatability
	}
}

// UpdatabilityClause is "FOR READ ONLY" (for_update is false), or "FOR UPDATE"
// with an optional list of the columns that can be updated.
struct UpdatabilityClause {
	for_update bool
	columns    []Identifier
}

// new_cursor_specification is a query with an <updatability clause>, which is a
// <dynamic select statement>.
//
// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Format
fn new_cursor_specification(query QueryExpression, updatability UpdatabilityClause) QueryExpression {
	return QueryExpression{
		...query
		updatability: updatability
	}
}

// Cursor is both the cursor declaration descriptor and the cursor instance
// descriptor of a standing cursor (ISO/IEC 9075-2:2016(E), 4.38.2). The rows
// of an open cursor are a copy, so a change by another statement isn't visible
// through it, and nothing is disallowed.
//
// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>, General Rules, 4
// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 4
// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, General Rules, 4
struct Cursor {
	name string
	hold bool
	// scroll is true for a SCROLL cursor, which can be fetched in any direction
	// (see FetchOrientation), rather than only NEXT.
	scroll bool
	query  QueryExpression
	// params are the values of the dynamic parameters of the DECLARE CURSOR,
	// which are used each time the cursor is opened. writes is true if the
	// query contains a NEXT VALUE FOR (see PreparedStmt.writes).
	params map[string]Value
	writes bool
	// table is the table that a positioned DELETE or UPDATE changes, or none if
	// the cursor isn't updatable. If update_columns isn't empty, only those
	// columns can be changed by a positioned UPDATE. sort_columns can't be changed
	// by a positioned UPDATE (see DeclareCursor.sort_columns).
	table          ?Identifier
	update_columns []string
	sort_columns   []string
mut:
	// While the cursor is open, rows are all of the rows of the result (they
	// are found when it's opened) and position is the current row, which is -1
	// before the first row, and rows.len after the last row. on_row is false
	// when the cursor isn't positioned on a row, including after the current
	// row is deleted (then it's before the next row, see Cursor.move).
	is_open  bool
	columns  Columns
	rows     []Row
	position int
	on_row   bool
	// fetched is true if a FETCH has been executed in the current transaction.
	// A holdable cursor must be fetched in a transaction before its current row
	// can be changed (ISO/IEC 9075-2:2016(E), 15.5, General Rules, 7).
	fetched bool
	// row_states has what has happened to each of rows since the cursor was
	// opened (see Connection.note_row_changes).
	row_states []CursorRowState
}

// CursorRowState is what has happened to a row of an open cursor. The row
// itself (in Cursor.rows) has the id and tid of the current version of the row
// in the table.
struct CursorRowState {
mut:
	// changed is true if the row was changed by a statement other than a
	// positioned DELETE or UPDATE of this cursor.
	changed bool
	// positioned is true if the row was changed by a positioned DELETE or UPDATE
	// of this cursor.
	positioned bool
	// deleted is true if the row is gone. Another row can get the same id, by
	// having the same PRIMARY KEY, but it isn't this row. changed is false if
	// the row was deleted through this cursor.
	deleted bool
}

fn (stmt DeclareCursor) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration, writes bool) !Result {
	t := start_timer()

	if stmt.name in conn.cursors {
		return sqlstate_42p03(stmt.name)
	}

	// The query is planned to find any errors (such as a table that doesn't
	// exist) before the cursor is declared.
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	plan := create_plan(stmt.query, params, mut conn)!
	simply_updatable := stmt.simply_updatable(plan, params, mut conn)!

	// A cursor is updatable if it's FOR UPDATE, or if it has no <updatability
	// clause>, isn't SCROLL, has no ORDER BY, and the query is simply updatable.
	// A SCROLL cursor that's FOR UPDATE is updatable (F831-01). The columns of
	// FOR UPDATE OF must be in the table.
	//
	// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Syntax Rules, 4 to 9
	mut table := ?Identifier(none)
	mut update_columns := []string{}
	if updatability := stmt.updatability {
		if updatability.for_update {
			if !simply_updatable {
				return sqlstate_42601('cursor ${stmt.name} is not updatable')
			}
			table_name := stmt.table_name(mut conn)!
			// create_plan has already found the table.
			target := unsafe { conn.catalog_for(table_name).storage.tables[table_name.storage_id()] }
			for column in updatability.columns {
				target.column(column.sub_entity_name)!
				update_columns << column.sub_entity_name
			}
			table = table_name
		}
	} else if simply_updatable && !stmt.scroll && stmt.query.order.len == 0 {
		table = stmt.table_name(mut conn)!
	}

	mut sort_columns := []string{}
	if cursor_table := table {
		sort_columns = stmt.sort_columns(cursor_table, params, mut conn)!
	}

	conn.cursors[stmt.name] = &Cursor{
		name:           stmt.name
		hold:           stmt.hold
		scroll:         stmt.scroll
		query:          stmt.query
		params:         params
		writes:         writes
		table:          table
		update_columns: update_columns
		sort_columns:   sort_columns
	}

	return new_result_msg('DECLARE CURSOR', elapsed_parse, t.elapsed())
}

// simply_updatable is true if the query is a simply updatable <query
// specification>, which can be changed through the cursor. It must select from
// one table, without grouping (or an aggregate function) or DISTINCT. Each item
// of the select list must be a different column of the table, and a subquery in
// the WHERE can't read the table.
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 24 to 27
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 7 and 9
fn (stmt DeclareCursor) simply_updatable(plan Plan, params map[string]Value, mut conn Connection) !bool {
	body := stmt.query.body
	if body !is QuerySpecification || stmt.query.offset != none || stmt.query.fetch != none {
		return false
	}

	query := body as QuerySpecification
	from_clause := query.table_expression.from_clause
	if from_clause !is TablePrimary || (from_clause as TablePrimary).body !is Identifier {
		return false
	}

	for operation in plan.operations {
		if operation is GroupOperation || operation is DistinctOperation
			|| operation is VirtualTableOperation || operation is SingleRowOperation {
			return false
		}
	}

	if !query.has_only_distinct_columns() {
		return false
	}

	if query.table_expression.where_clause != none {
		return stmt.table_name(mut conn)!.id() !in conn.tables_of_subqueries(query, params)!
	}

	return true
}

// has_only_distinct_columns is true if each item of the select list is a column
// reference, and no column is referenced more than once. A qualified asterisk
// is every column of the only table, so it can't be used with another item.
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 24.b, 25.a and 27.c
fn (e QuerySpecification) has_only_distinct_columns() bool {
	match e.exprs {
		AsteriskExpr {
			return true
		}
		[]SelectSublist {
			mut columns := []string{}
			for item in e.exprs {
				match item {
					DerivedColumn {
						column := item.column_reference() or { return false }
						if column.sub_entity_name in columns {
							return false
						}
						columns << column.sub_entity_name
					}
					QualifiedAsteriskExpr {
						if e.exprs.len > 1 {
							return false
						}
					}
				}
			}

			return true
		}
	}
}

// tables_of_subqueries returns the id of each table that a subquery of a simply
// updatable query reads, however deeply it's nested (such as in a join or in a
// derived table of the subquery). The query is planned again because that's the
// only way to reach them, and without the ORDER BY because only the WHERE counts,
// which is the only other place in the query that a subquery could be.
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 27.d
fn (mut conn Connection) tables_of_subqueries(query QuerySpecification, params map[string]Value) ![]string {
	conn.collect_subquery_tables = true
	defer {
		conn.collect_subquery_tables = false
		conn.subquery_tables = []
	}

	create_plan(QueryExpression{ body: query }, params, mut conn)!

	return conn.subquery_tables.clone()
}

// table_name is the table of a simply updatable query.
fn (stmt DeclareCursor) table_name(mut conn Connection) !Identifier {
	body := stmt.query.body as QuerySpecification
	from_clause := body.table_expression.from_clause as TablePrimary

	return conn.resolve_table_identifier(from_clause.body as Identifier, false)
}

// sort_columns returns the columns of the table of an updatable cursor that are
// generally underlying columns of a sort key. That's every column identified by
// a column reference in the sort key, even inside of a subquery, but not a column
// of another table that has the same name. A correlation name can rename the
// columns. A sort key without a column reference has no underlying columns, so
// "ORDER BY 1" doesn't use any (it isn't the first column of the result).
//
// A sort key that's only a name is the column of the result with that name
// (#332), so the columns of that <derived column> are included. A column of the
// table with the same name is also included, because that's what the rows are
// actually ordered by until then.
//
// ISO/IEC 9075-2:2016(E), 6.28, <value expression>, Syntax Rules, 6
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 10
// ISO/IEC 9075-2:2016(E), 14.13, <update statement: positioned>, Syntax Rules, 13
fn (stmt DeclareCursor) sort_columns(table_name Identifier, params map[string]Value, mut conn Connection) ![]string {
	if stmt.query.order.len == 0 {
		return []
	}

	conn.collect_columns = true
	defer {
		conn.collect_columns = false
		conn.collected_columns = map[string]bool{}
		conn.correlated_columns = map[string][]string{}
	}

	// The tables are planned again because they aren't kept in the plan. This also
	// finds where the columns of a correlation name come from. Nothing that's
	// compiled by this (such as the WHERE) is a sort key.
	_, tables := create_basic_plan(stmt.query.body, params, mut conn, true, Correlation{})!
	conn.collected_columns = map[string]bool{}

	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}
	for spec in stmt.query.order {
		spec.expr.compile(mut c)!
		stmt.compile_result_column(spec, mut c)!
	}

	// create_plan has already found the table.
	table := unsafe { conn.catalog_for(table_name).storage.tables[table_name.storage_id()] }

	return table.columns.filter(it.name.id() in conn.collected_columns).map(it.name.sub_entity_name)
}

// compile_result_column compiles the <derived column> that a sort key is the
// name of, if any.
fn (stmt DeclareCursor) compile_result_column(spec SortSpecification, mut c Compiler) ! {
	name := DerivedColumn{
		expr: spec.expr
	}.column_reference() or { return }

	exprs := (stmt.query.body as QuerySpecification).exprs
	if name.entity_name == '' && exprs is []SelectSublist {
		for item in exprs {
			if item is DerivedColumn && item.as_clause.sub_entity_name == name.sub_entity_name {
				item.expr.compile(mut c)!
			}
		}
	}
}

// collect_column adds the column that a column reference identifies to the
// collected columns. It's in the innermost query that has a column with the
// name, see Identifier.compile_column.
fn (mut conn Connection) collect_column(e Identifier, tables map[string]&Table) {
	mut scopes := conn.subquery_scopes.map(it.tables)
	scopes << tables
	for i := scopes.len - 1; i >= 0; i-- {
		for _, table in scopes[i] {
			if e.is_column_of_table(conn, table) {
				column := table.column(e.sub_entity_name) or { continue }
				conn.collect_column_id(column.name.id())
				return
			}
		}
	}
}

// collect_column_id adds a column, and the columns that it comes from if it's a
// column of a correlation name. A subquery can use the same correlation name, so
// there can be more than one, and they can refer to each other.
fn (mut conn Connection) collect_column_id(id string) {
	if id !in conn.collected_columns {
		conn.collected_columns[id] = true
		for source in conn.correlated_columns[id] {
			conn.collect_column_id(source)
		}
	}
}

fn (stmt DeclareCursor) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DECLARE CURSOR')
}

// cursor returns the cursor that has been declared with the name.
//
// ISO/IEC 9075-2:2016(E), 14.4, <open statement>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, Syntax Rules, 3
// ISO/IEC 9075-2:2016(E), 14.6, <close statement>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 14.13, <update statement: positioned>, Syntax Rules, 1
fn (mut conn Connection) cursor(name string) !&Cursor {
	return conn.cursors[name] or { return sqlstate_34000('cursor ${name} does not exist') }
}

// open_cursor returns the cursor with the name, which must be open.
//
// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, General Rules, 2
// ISO/IEC 9075-2:2016(E), 15.3, Determination of the current row of a cursor, General Rules, 2
// ISO/IEC 9075-2:2016(E), 15.4, Effect of closing a cursor, General Rules, 2
fn (mut conn Connection) open_cursor(name string) !&Cursor {
	cursor := conn.cursor(name)!
	if !cursor.is_open {
		return sqlstate_24000(name, 'cursor ${name} is not open')
	}

	return cursor
}

// open_cursor executes a query, like query, and opens a cursor with the name
// on its result. It's the same as a DECLARE CURSOR (that is holdable if hold is
// true) and OPEN, so a positioned DELETE or UPDATE (WHERE CURRENT OF name) can
// change the row that the cursor is on (see Connection.position_cursor). The
// cursor must be removed with Connection.remove_cursor when it's closed. This
// is the cursor of a dynamic select statement in the SQL/CLI (libvsql).
//
// The cursor is closed when the transaction ends (a holdable cursor stays open
// after a commit), so it must be opened in a transaction. The statement must
// be a query, which can end with an <updatability clause> (FOR READ ONLY, or
// FOR UPDATE with an optional list of the columns that a positioned UPDATE can
// set). Without one, the cursor is updatable if the query is simply updatable
// and has no ORDER BY.
//
// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Syntax Rules, 4 and 6
pub fn (mut p PreparedStmt) open_cursor(name string, hold bool, params map[string]Value) !Result {
	t := start_timer()
	query := p.stmt as QueryExpression
	mut declare_stmt := PreparedStmt{
		...p
		stmt: DeclareCursor{
			name:         name
			hold:         hold
			query:        query
			updatability: query.updatability
		}
	}
	declare_stmt.query(params)!

	mut open_stmt := PreparedStmt{
		...p
		stmt: OpenStatement{name}
	}
	// A cursor that couldn't be opened (or was closed by the end of the
	// transaction) isn't declared, so the name can be used again.
	open_stmt.query(params) or {
		p.c.remove_cursor(name)
		return err
	}
	cursor := p.c.open_cursor(name) or {
		p.c.remove_cursor(name)
		return err
	}

	return new_result(cursor.columns, cursor.rows, p.elapsed_parse, t.elapsed())
}

// position_cursor positions an open cursor on a row of its result (starting at
// 0), or on no row if row is outside of the result. The row is then the current
// row of the cursor for a positioned DELETE or UPDATE. This is for a cursor
// opened by PreparedStmt.open_cursor that has been fetched by the SQL/CLI.
pub fn (mut conn Connection) position_cursor(name string, row int) ! {
	mut cursor := conn.open_cursor(name)!
	cursor.position = row
	cursor.on_row = row >= 0 && row < cursor.rows.len
	cursor.fetched = true
}

// close_cursor closes a cursor, if there is one with the name, but it's still
// declared. A positioned DELETE or UPDATE of it is then an invalid cursor state
// (rather than an invalid cursor name), until it's removed by remove_cursor.
// This is for a cursor opened by PreparedStmt.open_cursor.
//
// ISO/IEC 9075-2:2016(E), 15.4, Effect of closing a cursor, General Rules, 4-6
pub fn (mut conn Connection) close_cursor(name string) {
	mut cursor := conn.cursors[name] or { return }
	cursor.close()
}

// remove_cursor closes and removes a cursor, if there is one with the name.
// Another cursor can then be declared (or opened) with the name.
pub fn (mut conn Connection) remove_cursor(name string) {
	conn.cursors.delete(name)
}

// end_transaction closes the cursors when a transaction ends. A holdable
// cursor stays open after a commit.
//
// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 3
// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.e
fn (mut conn Connection) end_transaction(commit bool) {
	// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 7
	// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.c
	conn.savepoints = []Savepoint{}

	for _, mut cursor in conn.cursors {
		if !commit || !cursor.hold {
			cursor.close()
		}
		cursor.fetched = false
	}
}

// close puts the cursor into the closed state, and destroys its result.
//
// ISO/IEC 9075-2:2016(E), 15.4, Effect of closing a cursor, General Rules, 4-6
fn (mut cursor Cursor) close() {
	cursor.is_open = false
	cursor.rows = []Row{}
	cursor.row_states = []CursorRowState{}
	cursor.on_row = false
}

// current_row is the row of the table that the cursor is positioned on, for a
// positioned DELETE or UPDATE of table_name. The cursor must be updatable, and
// table_name must be its table. A holdable cursor must have been fetched in
// the current transaction.
//
// ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>, Syntax Rules, 4 and 6
// ISO/IEC 9075-2:2016(E), 14.13, <update statement: positioned>, Syntax Rules, 4 and 6
// ISO/IEC 9075-2:2016(E), 15.5, Effect of a positioned delete, General Rules, 6 and 7
// ISO/IEC 9075-2:2016(E), 15.6, Effect of a positioned update, General Rules, 6 and 7
fn (mut conn Connection) current_row(name string, table_name Identifier) !&Cursor {
	mut cursor := conn.cursor(name)!
	table := cursor.table or { return sqlstate_34000('cursor ${name} is not updatable') }
	if conn.resolve_table_identifier(table_name, false)!.id() != table.id() {
		return sqlstate_42601('table ${table_name} is not the table of cursor ${name}')
	}

	if !cursor.is_open {
		return sqlstate_24000(name, 'cursor ${name} is not open')
	}

	if !cursor.on_row {
		return sqlstate_24000(name, 'cursor ${name} is not positioned on a row')
	}

	if cursor.hold && !cursor.fetched {
		return sqlstate_24000(name, 'cursor ${name} has not been fetched in this transaction')
	}

	// The SQL/CLI can scroll back to a row that was deleted through the cursor.
	// Another statement deleting the row isn't an exception, it's a warning (see
	// note_row_changes).
	state := cursor.row_states[cursor.position]
	if state.deleted && !state.changed {
		return sqlstate_24000(name, 'the current row of cursor ${name} has been deleted')
	}

	return cursor
}

// current_rows returns the row in rows that the cursor (if any) is positioned
// on. A positioned DELETE or UPDATE is a searched one that only changes that
// row, which is none if the row has been deleted.
//
// A row is identified by its id rather than its values (which is
// implementation-dependent), so a row that another statement has updated is
// still found, and is changed.
//
// ISO/IEC 9075-2:2016(E), 15.5, Effect of a positioned delete, General Rules, 9
// ISO/IEC 9075-2:2016(E), 15.6, Effect of a positioned update, General Rules, 16
fn current_rows(rows []Row, current_of ?&Cursor) []Row {
	cursor := current_of or { return rows }
	if cursor.row_states[cursor.position].deleted {
		return []Row{}
	}
	id := cursor.rows[cursor.position].id

	return rows.filter(it.id == id)
}

// has_open_cursor is true if any cursor of the connection is open.
fn (conn &Connection) has_open_cursor() bool {
	for _, cursor in conn.cursors {
		if cursor.is_open {
			return true
		}
	}

	return false
}

// note_row_changes is called once a statement can no longer fail, with the rows
// of table that it identified (rows) and the rows that it deleted or replaced
// (changes, since an UPDATE doesn't write a row that has the same values).
// current_of is the cursor of a positioned DELETE or UPDATE, or none for a
// searched DELETE or UPDATE and for the rows of a referential action.
//
// A warning (cursor operation conflict) is raised when a positioned statement
// changes a row that was changed, while the cursor is open, by another
// statement. That's found by what this function records, and by the tid of the
// row for a transaction of another connection. It's also raised when any other
// statement changes a row that was changed by a positioned statement of some
// open cursor. The cursors of another connection aren't known, so this can't
// be raised for them. A row that was deleted through the cursor can't be changed
// by a later statement, so it never causes a warning in that direction. A
// referential action isn't one of the statements that 15.5 and 15.6 name, but
// it's a change by another statement all the same.
//
// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>, General Rules, 9
// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, General Rules, 8
// ISO/IEC 9075-2:2016(E), 15.5, Effect of a positioned delete, General Rules, 12
// ISO/IEC 9075-2:2016(E), 15.6, Effect of a positioned update, General Rules, 9
// ISO/IEC 9075-2:2016(E), 15.17, Execution of referential actions, General Rules, 14
fn (mut conn Connection) note_row_changes(table Table, rows []Row, changes []RowChange, current_of ?&Cursor) ! {
	mut own_cursor := ''
	if cursor := current_of {
		own_cursor = cursor.name
		if rows.len == 0 || cursor.row_states[cursor.position].changed
			|| rows[0].tid != cursor.rows[cursor.position].tid {
			conn.add_warning(sqlstate_01001(cursor.name))
		}
	}

	// The rows are only looked for in the open cursors.
	if rows.len == 0 || !conn.has_open_cursor() {
		return
	}

	mut identified := map[string]bool{}
	for row in rows {
		identified[row.id.bytestr()] = true
	}
	mut changed := map[string]RowChange{}
	for change in changes {
		changed[change.old.id.bytestr()] = change
	}
	tid := conn.catalog_for(table.name).storage.transaction_id

	for _, mut cursor in conn.cursors {
		cursor_table := cursor.table or { continue }
		if !cursor.is_open || cursor_table.id() != table.name.id() {
			continue
		}

		is_own := cursor.name == own_cursor
		mut is_conflict := false
		for i, row in cursor.rows {
			id := row.id.bytestr()
			if cursor.row_states[i].deleted || id !in identified {
				continue
			}

			if is_own {
				cursor.row_states[i].positioned = true
			} else {
				is_conflict = is_conflict || cursor.row_states[i].positioned
				cursor.row_states[i].changed = true
			}

			// The rows of the cursor follow the row, so that a change to a
			// PRIMARY KEY doesn't lose it, even if two rows swap their keys.
			change := changed[id] or { continue }
			if change.is_delete {
				cursor.row_states[i].deleted = true
				if is_own {
					cursor.row_states[i].changed = false
				}
			} else {
				mut new_row := change.new
				new_row.object_key(table)!
				cursor.rows[i].id = new_row.id
				cursor.rows[i].tid = tid
			}
		}

		if is_conflict && own_cursor == '' {
			conn.add_warning(sqlstate_01001(cursor.name))
		}
	}
}

// ModuleCursor is a <declare cursor> in an SQL-client module. Each SQL-session
// has a CLI statement for the cursor, with the cursor name (sql_name is the
// name as a delimited identifier, for SQLSetCursorName), which is opened by
// an OPEN with the query. The host parameters of the query are the host
// parameters of the procedure that opens it. index is the position of the
// cursor in the module, and degree is the number of columns of the query, or
// -1 if it isn't known until it's opened. The cursor instance of an
// SQL-session is closed until it's opened.
//
// A <dynamic declare cursor> has the name of a prepared statement instead of a
// query, which is its origin.
//
// ISO/IEC 9075-2:2016(E), 20.15, <dynamic declare cursor>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 20.15, <dynamic declare cursor>, General Rules, 1
// ISO/IEC 9075-2:2016(E), 14.1, <declare cursor>, Syntax Rules, 1.b and 1.c
// ISO/IEC 9075-2:2016(E), 14.1, <declare cursor>, General Rules, 1
// ISO/IEC 9075-2:2016(E), 13.3, <externally-invoked procedure>, General Rules, 9
struct ModuleCursor {
	index     int
	name      string
	sql_name  string
	hold      bool
	query     string
	degree    int
	statement string
	// features are the features that the declaration uses.
	features []string
}

// begin is begin for a statement of the cursor, which is also the cursor of any
// invalid cursor state that the statement raises.
//
// ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 4.i
fn (cursor ModuleCursor) begin(command_function string, code int) string {
	return begin(command_function, code) + '  vsql_m_da.cursor_name = ${c_string(cursor.name)};\n'
}

// declare_module_cursor reads the <declare cursor> of a module. It's parsed
// with a "?" for each host parameter, to find any syntax errors.
fn declare_module_cursor(text string, index int) !ModuleCursor {
	tokens := tokenize(text)!
	if tokens.any(it.token == token_operator_question_mark) {
		return sqlstate_42601('a module cannot contain a dynamic parameter (?), use a host parameter (:name)')
	}

	// A <dynamic declare cursor> is FOR a <statement name>, which is one
	// identifier. Its <cursor properties> are found by parsing it with a query
	// instead.
	//
	// ISO/IEC 9075-2:2016(E), 20.15, <dynamic declare cursor>, General Rules, 1.e
	// ISO/IEC 9075-2:2016(E), 20.15, <dynamic declare cursor>, Conformance Rules, 1
	query := cursor_specification(text)!
	mut statement := ''
	mut q := new_module_tokens(query)!
	if q.tokens.len == 1 {
		statement = q.identifier('statement name')!
	}
	declaration_text := if statement == '' {
		text
	} else {
		text.runes()[..text.runes().len - query.runes().len].string() + ' SELECT 1 FROM t'
	}

	text_sql, _ := replace_host_parameters(declaration_text, fn (_ string) !string {
		return '?'
	})!
	// The text starts with DECLARE, so it's a <declare cursor> if it parses.
	stmt, mut features := parse_module_sql(text_sql)!
	declaration := stmt as DeclareCursor
	if statement != '' {
		features << 'B031'
	}
	body := declaration.query.body
	degree := if body is QuerySpecification && statement == '' {
		select_list_degree(body.exprs)
	} else {
		-1
	}

	return ModuleCursor{
		index:     index
		name:      declaration.name
		sql_name:  '"' + declaration.name.replace('"', '""') + '"'
		hold:      declaration.hold
		query:     if statement == '' { query } else { '' }
		degree:    degree
		statement: statement
		features:  features
	}
}

// cursor_specification is the text after the first FOR (that isn't in a
// delimited identifier or a comment) of a <declare cursor>, which is the
// query, including any <updatability clause> (the SQL/CLI opens a cursor with
// one, see PreparedStmt.open_cursor). There can't be a literal before it.
fn cursor_specification(text string) !string {
	cs := text.runes()
	mut i := 0
	for i < cs.len {
		if is_comment(cs, i) {
			i = skip_comment(cs, i)!
		} else if cs[i] == `"` {
			i = skip_delimited_identifier(cs, i)
		} else if is_identifier_char(cs[i], false) {
			start := i
			for i < cs.len && is_identifier_char(cs[i], true) {
				i++
			}
			if cs[start..i].string().to_upper() == 'FOR' {
				break
			}
		} else {
			i++
		}
	}

	return cs[i..].string()
}

// find_module_cursor is the cursor with the name, in the cursors that are
// declared before the procedure.
//
// ISO/IEC 9075-2:2016(E), 13.1, <SQL-client module definition>, Syntax Rules, 11 and 12
fn find_module_cursor(cursors []ModuleCursor, name string, p ExternallyInvokedProcedure) !ModuleCursor {
	for cursor in cursors {
		if cursor.name == name {
			return cursor
		}
	}

	return sqlstate_42601('procedure ${p.name}: cursor ${name} must be declared before it is used')
}

// module_cursor reads the <cursor name> of an OPEN, FETCH or CLOSE in a module.
fn (mut t ModuleTokens) module_cursor(p ExternallyInvokedProcedure, cursors []ModuleCursor) !ModuleCursor {
	return find_module_cursor(cursors, t.identifier('cursor name')!, p)
}

// end_of_statement checks that there's nothing after the statement.
fn (t ModuleTokens) end_of_statement(p ExternallyInvokedProcedure) ! {
	if t.pos < t.tokens.len {
		return sqlstate_42601('procedure ${p.name}: unexpected${t.near()}')
	}
}
