module vsql

// ISO/IEC 9075-2:2016(E), 7.6, <table reference>
//
// Reference a table.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.15.11, Range variables

struct Correlation {
	name    Identifier
	columns []Identifier
}

struct TablePrimary {
	body        TablePrimaryBody
	correlation Correlation
}

type TableReference = QualifiedJoin | TablePrimary

fn (e TableReference) pstr(params map[string]Value) string {
	match e {
		QualifiedJoin {
			return '${e.left_table.pstr(params)} ${e.join_type} JOIN ${e.right_table.pstr(params)} ${e.specification.pstr(params)}'
		}
		TablePrimary {
			mut s := match e.body {
				Identifier { e.body.str() }
				QueryExpression { '(${e.body.pstr(params)})' }
				DataChangeDeltaTable { e.body.str() }
			}

			if e.correlation.name.sub_entity_name != '' {
				s += ' AS ${e.correlation.name}'
			}

			if e.correlation.columns.len > 0 {
				mut columns := []string{}
				for column in e.correlation.columns {
					columns << column.str()
				}
				s += ' (${columns.join(', ')})'
			}

			return s
		}
	}
}

enum JoinType {
	inner
	left
	right
}

fn (t JoinType) str() string {
	return match t {
		.inner { 'INNER' }
		.left { 'LEFT' }
		.right { 'RIGHT' }
	}
}

// left_table and right_table are references because a TableReference can be a
// QualifiedJoin, and V stores a sum type's value inline.
struct QualifiedJoin {
	left_table    &TableReference
	join_type     JoinType
	right_table   &TableReference
	specification JoinSpecification
}

// A JoinSpecification is an ON condition, or the columns of a USING.
type JoinSpecification = BooleanValueExpression | []Identifier

fn (e JoinSpecification) pstr(params map[string]Value) string {
	return match e {
		BooleanValueExpression {
			'ON ${e.pstr(params)}'
		}
		[]Identifier {
			'USING (${e.map(it.str()).join(', ')})'
		}
	}
}

fn new_qualified_join(left_table TableReference, join_type JoinType, right_table TableReference, specification JoinSpecification) QualifiedJoin {
	return QualifiedJoin{&left_table, join_type, &right_table, specification}
}

// new_cross_join is a comma in FROM: the same as an inner join with a condition
// that's always true.
//
// ISO/IEC 9075-2:2016(E), 7.5, <from clause>, General Rules, 1.b
fn new_cross_join(left_table TableReference, right_table TableReference) QualifiedJoin {
	return new_qualified_join(left_table, .inner, right_table, BooleanValueExpression{
		term: BooleanTerm{
			factor: new_boolean_test(BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_boolean_value(true))))),
				false, none, false)
		}
	})
}

// A DataChangeDeltaTable is the rows that an INSERT, UPDATE or DELETE changes,
// such as "FINAL TABLE (INSERT INTO t VALUES 1)". result_option is 'FINAL',
// 'NEW' or 'OLD'. The statement is run when the rows are read, see
// DataChangeOperation.
struct DataChangeDeltaTable {
	result_option string
	stmt          DataChangeStatement
}

type DataChangeStatement = DeleteStatementSearched | InsertStatement | UpdateStatementSearched

fn new_data_change_delta_table(result_option string, stmt Stmt) DataChangeDeltaTable {
	return DataChangeDeltaTable{
		result_option: result_option
		stmt:          match stmt {
			DeleteStatementSearched { DataChangeStatement(stmt) }
			UpdateStatementSearched { DataChangeStatement(stmt) }
			else { DataChangeStatement(stmt as InsertStatement) }
		}
	}
}

fn (d DataChangeDeltaTable) str() string {
	return '${d.result_option} TABLE (${d.stmt.name()} ${d.stmt.table_name()})'
}

// name is the keywords that the statement starts with.
fn (stmt DataChangeStatement) name() string {
	return match stmt {
		DeleteStatementSearched { 'DELETE FROM' }
		InsertStatement { 'INSERT INTO' }
		UpdateStatementSearched { 'UPDATE' }
	}
}

// table_name is the table that the statement changes (its subject table).
fn (stmt DataChangeStatement) table_name() Identifier {
	return match stmt {
		DeleteStatementSearched { stmt.table_name }
		InsertStatement { stmt.table_name }
		UpdateStatementSearched { stmt.table_name }
	}
}

// change runs the statement and returns the rows that it changed.
fn (stmt DataChangeStatement) change(mut conn Connection, params map[string]Value) !DataChange {
	return match stmt {
		DeleteStatementSearched { stmt.change(mut conn, params)! }
		InsertStatement { stmt.change(mut conn, params)! }
		UpdateStatementSearched { stmt.change(mut conn, params)! }
	}
}

// data_change_name is the name of the statement ('INSERT', 'UPDATE' or 'DELETE')
// of the data change delta table that the query reads, or empty if it doesn't
// read one. Such a query changes the database, so it's an SQL-data change
// statement.
//
// ISO/IEC 9075-2:2016(E), 4.39.2.3, SQL-data change statements
fn (q QueryExpression) data_change_name() string {
	body := q.body
	if body is QuerySpecification {
		from_clause := body.table_expression.from_clause
		if from_clause is TablePrimary {
			table_body := from_clause.body
			if table_body is DataChangeDeltaTable {
				return table_body.stmt.name().all_before(' ')
			}
		}
	}

	return ''
}

// data_change_name is the data_change_name of a query, or of the query of a
// DECLARE CURSOR, see QueryExpression.data_change_name.
fn data_change_name(stmt Stmt) string {
	return match stmt {
		DeclareCursor { stmt.query.data_change_name() }
		QueryExpression { stmt.data_change_name() }
		else { '' }
	}
}

// cursor_data_change_name is the data_change_name of the query of a cursor, so
// opening it changes the database. It's empty if there's no cursor.
fn (conn &Connection) cursor_data_change_name(name string) string {
	cursor := conn.cursors[name] or { return '' }

	return cursor.query.data_change_name()
}

// A DataChange is the rows that an INSERT, UPDATE or DELETE changed, as they're
// stored (see Row.for_storage), in the order that they were changed. old has
// each row that an UPDATE or DELETE identified as it was before, and new has
// each row that an INSERT or UPDATE identified as it is after. A row that an
// UPDATE doesn't change is in both.
struct DataChange {
	old []Row
	new []Row
}

// A DataChangeOperation runs the statement of a data change delta table, then
// returns its old or new rows. Its columns are the columns of the table that
// the statement changes.
//
// ISO/IEC 9075-2:2016(E), 7.6, <table reference>, Syntax Rules, 10.c
struct DataChangeOperation {
	delta  DataChangeDeltaTable
	table  Table
	params map[string]Value
mut:
	conn &Connection
}

// new_data_change_operation returns an error if the result option can't be used
// for the statement: an INSERT has no old rows, and a DELETE has no new rows.
//
// ISO/IEC 9075-2:2016(E), 7.6, <table reference>, Syntax Rules, 10, 10.a.i and 10.a.ii
fn new_data_change_operation(delta DataChangeDeltaTable, params map[string]Value, mut conn Connection) !DataChangeOperation {
	if (delta.stmt is InsertStatement && delta.result_option == 'OLD')
		|| (delta.stmt is DeleteStatementSearched && delta.result_option != 'OLD') {
		return sqlstate_42601('${delta.result_option} TABLE cannot be used with ${delta.stmt.name().all_before(' ')}')
	}

	return DataChangeOperation{delta, conn.resolved_table(delta.stmt.table_name())!, params, conn}
}

fn (o DataChangeOperation) str() string {
	columns := o.columns().map(Column{
		name:     Identifier{
			sub_entity_name: it.name.sub_entity_name
		}
		typ:      it.typ
		not_null: it.not_null
	})

	return '${o.delta} (${Columns(columns)})'
}

fn (o DataChangeOperation) columns() Columns {
	return o.table.result_columns()
}

// execute runs the statement. While the statement of a FINAL TABLE runs, its
// table can't be changed by anything else that the statement causes, such as
// a referential action.
//
// ISO/IEC 9075-2:2016(E), 7.6, <table reference>, General Rules, 5, 5.a and 5.c
fn (mut o DataChangeOperation) execute(_ []Row) ![]Row {
	mut conn := o.conn
	if o.delta.result_option == 'FINAL' {
		conn.restricted_tables << o.table.name.storage_id()
	}
	defer {
		if o.delta.result_option == 'FINAL' {
			conn.restricted_tables.delete_last()
		}
	}

	change := o.delta.stmt.change(mut conn, o.params)!

	// ISO/IEC 9075-2:2016(E), 7.6, <table reference>, General Rules, 5.b
	return if o.delta.result_option == 'OLD' { change.old } else { change.new }
}
