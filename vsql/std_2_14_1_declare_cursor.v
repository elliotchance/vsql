module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.1, <declare cursor>
//
// Declare a standing cursor.

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
// descriptor of a standing cursor (ISO/IEC 9075-2:2016(E), 4.38.2).
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
	// can be changed (ISO/IEC 9075-2:2016(E), 15.5, General Rule 7).
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

	// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Syntax Rules 4 to 6
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
// specification> (ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax
// Rule 21), which can be changed through the cursor. It must select from one
// table, without grouping (or an aggregate function) or DISTINCT.
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
fn (mut conn Connection) cursor(name string) !&Cursor {
	return conn.cursors[name] or { return sqlstate_34000('cursor ${name} does not exist') }
}

// open_cursor returns the cursor with the name, which must be open.
fn (mut conn Connection) open_cursor(name string) !&Cursor {
	cursor := conn.cursor(name)!
	if !cursor.is_open {
		return sqlstate_24000('cursor ${name} is not open')
	}

	return cursor
}

// end_transaction closes the cursors when a transaction ends (ISO/IEC
// 9075-2:2016(E), 17.7, General Rule 10g and 17.8, General Rule 2e). A
// holdable cursor stays open after a commit.
fn (mut conn Connection) end_transaction(commit bool) {
	for _, mut cursor in conn.cursors {
		if !commit || !cursor.hold {
			cursor.close()
		}
		cursor.fetched = false
	}
}

// close puts the cursor into the closed state (ISO/IEC 9075-2:2016(E), 15.4,
// Effect of closing a cursor).
fn (mut cursor Cursor) close() {
	cursor.is_open = false
	cursor.rows = []Row{}
	cursor.on_row = false
}

// current_row is the row of the table that the cursor is positioned on, for a
// positioned DELETE or UPDATE of table_name (ISO/IEC 9075-2:2016(E), 14.8, Syntax
// Rules 4 and 6, and 15.5, General Rules 6 and 7).
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
// row.
fn current_rows(rows []Row, current_of ?&Cursor) ![]Row {
	cursor := current_of or { return rows }
	id := cursor.rows[cursor.position].id
	current := rows.filter(it.id == id)
	if current.len == 0 {
		return sqlstate_24000('the current row of cursor ${cursor.name} has been deleted')
	}

	return current
}
