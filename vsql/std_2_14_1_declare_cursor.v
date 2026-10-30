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
// a cursor by executing it is a vsql extension (V004-01). The cursor belongs to
// the connection (the SQL-session) until the connection is closed.
struct DeclareCursor {
	name         string
	hold         bool
	query        QueryExpression
	updatability ?UpdatabilityClause
}

// UpdatabilityClause is "FOR READ ONLY" (for_update is false), or "FOR UPDATE"
// with an optional list of the columns that can be updated.
struct UpdatabilityClause {
	for_update bool
	columns    []Identifier
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
	name  string
	hold  bool
	query QueryExpression
	// params are the values of the dynamic parameters of the DECLARE CURSOR,
	// which are used each time the cursor is opened. writes is true if the
	// query contains a NEXT VALUE FOR (see PreparedStmt.writes).
	params map[string]Value
	writes bool
	// table is the table that a positioned DELETE or UPDATE changes, or none if
	// the cursor isn't updatable. If update_columns isn't empty, only those
	// columns can be changed by a positioned UPDATE.
	table          ?Identifier
	update_columns []string
mut:
	// While the cursor is open, rows are all of the rows of the result (they
	// are found when it's opened) and position is the current row, which is -1
	// before the first row, and rows.len after the last row. on_row is false
	// when the cursor isn't positioned on a row, including after the current
	// row is deleted (then it's before the next row).
	is_open  bool
	columns  Columns
	rows     []Row
	position int
	on_row   bool
	// fetched is true if a FETCH has been executed in the current transaction.
	// A holdable cursor must be fetched in a transaction before its current row
	// can be changed (ISO/IEC 9075-2:2016(E), 15.5, General Rules, 7).
	fetched bool
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
	simply_updatable := stmt.simply_updatable(plan)

	// A cursor is updatable if it's FOR UPDATE, or if it has no <updatability
	// clause> and no ORDER BY, and the query is simply updatable. The columns of
	// FOR UPDATE OF aren't checked (#792).
	//
	// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Syntax Rules, 4 to 9
	mut table := ?Identifier(none)
	mut update_columns := []string{}
	if updatability := stmt.updatability {
		if updatability.for_update {
			if !simply_updatable {
				return sqlstate_42601('cursor ${stmt.name} is not updatable')
			}
			table = stmt.table_name(mut conn)!
		}
		for column in updatability.columns {
			update_columns << column.sub_entity_name
		}
	} else if simply_updatable && stmt.query.order.len == 0 {
		table = stmt.table_name(mut conn)!
	}

	conn.cursors[stmt.name] = &Cursor{
		name:           stmt.name
		hold:           stmt.hold
		query:          stmt.query
		params:         params
		writes:         writes
		table:          table
		update_columns: update_columns
	}

	return new_result_msg('DECLARE CURSOR', elapsed_parse, t.elapsed())
}

// simply_updatable is true if the query is a simply updatable <query
// specification>, which can be changed through the cursor. It must select from
// one table, without grouping (or an aggregate function) or DISTINCT. The
// select list and WHERE aren't checked (#778).
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 24, 26 and 27
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 7 and 9
fn (stmt DeclareCursor) simply_updatable(plan Plan) bool {
	body := stmt.query.body
	if body !is QuerySpecification || stmt.query.offset != none || stmt.query.fetch != none {
		return false
	}

	from_clause := (body as QuerySpecification).table_expression.from_clause
	if from_clause !is TablePrimary || (from_clause as TablePrimary).body !is Identifier {
		return false
	}

	for operation in plan.operations {
		if operation is GroupOperation || operation is DistinctOperation
			|| operation is VirtualTableOperation {
			return false
		}
	}

	return true
}

// table_name is the table of a simply updatable query.
fn (stmt DeclareCursor) table_name(mut conn Connection) !Identifier {
	body := stmt.query.body as QuerySpecification
	from_clause := body.table_expression.from_clause as TablePrimary

	return conn.resolve_table_identifier(from_clause.body as Identifier, false)
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
		return sqlstate_24000('cursor ${name} is not open')
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
// be a query.
pub fn (mut p PreparedStmt) open_cursor(name string, hold bool, params map[string]Value) !Result {
	t := start_timer()
	query := p.stmt as QueryExpression
	mut declare_stmt := PreparedStmt{
		...p
		stmt: DeclareCursor{
			name:  name
			hold:  hold
			query: query
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
		return sqlstate_24000('cursor ${name} is not open')
	}

	if !cursor.on_row {
		return sqlstate_24000('cursor ${name} is not positioned on a row')
	}

	if cursor.hold && !cursor.fetched {
		return sqlstate_24000('cursor ${name} has not been fetched in this transaction')
	}

	return cursor
}

// current_rows returns the row in rows that the cursor (if any) is positioned
// on. A positioned DELETE or UPDATE is a searched one that only changes that
// row. If another statement has deleted the row it's an error, and if another
// statement has updated it there's no warning, rather than a warning: cursor
// operation conflict (#797).
//
// ISO/IEC 9075-2:2016(E), 15.5, Effect of a positioned delete, General Rules, 9 and 12
// ISO/IEC 9075-2:2016(E), 15.6, Effect of a positioned update, General Rules, 9 and 16
// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>, General Rules, 9
// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, General Rules, 8
// ISO/IEC 9075-2:2016(E), 15.17, Execution of referential actions, General Rules, 14
fn current_rows(rows []Row, current_of ?&Cursor) ![]Row {
	cursor := current_of or { return rows }
	id := cursor.rows[cursor.position].id
	current := rows.filter(it.id == id)
	if current.len == 0 {
		return sqlstate_24000('the current row of cursor ${cursor.name} has been deleted')
	}

	return current
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
	query := cursor_specification(text)!
	mut statement := ''
	mut q := new_module_tokens(query)!
	if q.tokens.len == 1 {
		statement = q.identifier('statement name')!
	}
	declaration_text := if statement == '' {
		text
	} else {
		text.runes()[..text.runes().len - query.runes().len].string() + ' VALUES 1'
	}

	text_sql, _ := replace_host_parameters(declaration_text, fn (_ string) !string {
		return '?'
	})!
	// The text starts with DECLARE, so it's a <declare cursor> if it parses.
	declaration := parse_tokens(tokenize(text_sql)!)! as DeclareCursor
	if declaration.updatability != none {
		return sqlstate_42601('cursor ${declaration.name}: FOR READ ONLY and FOR UPDATE are not supported in a module')
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
	}
}

// cursor_specification is the text after the first FOR (that isn't in a
// delimited identifier or a comment) of a <declare cursor>, which is the
// query. There can't be a literal before it.
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

// find_module_cursor is the cursor that's declared in the module with the
// name.
fn find_module_cursor(cursors []ModuleCursor, name string, p ExternallyInvokedProcedure) !ModuleCursor {
	for cursor in cursors {
		if cursor.name == name {
			return cursor
		}
	}

	return sqlstate_42601('procedure ${p.name}: cursor ${name} is not declared')
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
