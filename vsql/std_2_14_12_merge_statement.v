module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>
//
// Conditionally update rows of a table, or insert new rows into a table.

struct MergeStatement {
	table_name Identifier
	// correlation_name is empty if there isn't one.
	correlation_name Identifier
	source           TablePrimary
	condition        BooleanValueExpression
	clauses          []MergeWhenClause
}

// A MergeWhenClause is a <merge when matched clause> (when matched is true),
// which updates the target row with set, or a <merge when not matched clause>,
// which inserts a row of values into columns (all of the columns when it's
// empty), with an <override clause> like an INSERT (see InsertStatement).
struct MergeWhenClause {
	matched bool
	// condition is the <search condition> after AND, if any.
	condition  ?BooleanValueExpression
	set        []SetClause
	columns    []Identifier
	overriding string
	values     []ContextuallyTypedRowValueConstructorElement
}

// A MergeSubject is a row of the target that a <merge when matched clause>
// (by its position) applies to, and how many rows of the source match it for
// that clause.
struct MergeSubject {
	clause  int
	row     Row
	matches int
}

// A MergeContext is what each row of a MERGE needs to work out its change.
struct MergeContext {
	table     Table
	target_id string
	// tables are the source and the target, and source_tables is only the source,
	// which is all that the VALUES of an INSERT can reference.
	tables        map[string]&Table
	source_tables map[string]&Table
	params        map[string]Value
	check         CheckConstraints
	generated     GeneratedColumns
mut:
	// compiled is the value of each <set clause>, compiled for the first row
	// and then kept for the rows after it, by the position of the clause and of
	// the <set clause>. conditions is the search condition of each clause, the
	// same way.
	compiled   map[string]CompileResult
	conditions map[int][]CompileResult
}

// first_clause is the position of the first clause for row whose search
// condition (if any) is true, only looking at the <merge when matched clause>s
// when row matched a row of the target, otherwise the <merge when not matched
// clause>s. It's -1 when there isn't one.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 6.a.i.1.A and 6.a.ii.5
fn (mut ctx MergeContext) first_clause(mut conn Connection, clauses []MergeWhenClause, row Row) !int {
	for i, clause in clauses {
		if clause.matched != (row.id.len > 0) {
			continue
		}
		condition := clause.condition or { return i }
		mut compiled := ctx.conditions[i] or { []CompileResult{cap: 1} }
		is_true := eval_as_bool(mut conn, row, condition, ctx.params, ctx.tables, mut compiled)!
		ctx.conditions[i] = compiled
		if is_true {
			return i
		}
	}

	return -1
}

// check returns an error when a <set clause> sets a column more than once, or
// an <insert column list> has a column more than once.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Syntax Rules, 19
// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>, Syntax Rules, 8
fn (stmt MergeStatement) check() ! {
	for clause in stmt.clauses {
		mut set_columns := map[string]bool{}
		for set in clause.set {
			if set.column_name in set_columns {
				return sqlstate_42601('column ${set.column_name} is set more than once')
			}
			set_columns[set.column_name] = true
		}

		mut insert_columns := map[string]bool{}
		for column in clause.columns {
			if column.sub_entity_name in insert_columns {
				return sqlstate_42601('column ${column.sub_entity_name} is specified more than once')
			}
			insert_columns[column.sub_entity_name] = true
		}
	}
}

// plan reads every row of the source, with the row of the target that it
// matches, or NULLs when it doesn't match one. That's a LEFT JOIN, so an index
// (or PRIMARY KEY) of the target can find the row that each row of the source
// matches. Each joined row has the id of its target row (see JoinOperation),
// and a row that doesn't match has none. The source and the target can't have
// the same name, like any two tables of a join.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Syntax Rules, 8, 9, 10 and 12
fn (stmt MergeStatement) plan(params map[string]Value, mut conn Connection) !(Plan, map[string]&Table) {
	return create_select_plan(QuerySpecification{
		exprs:            AsteriskExpr(true)
		table_expression: &TableExpression{
			from_clause: QualifiedJoin{
				left_table:    &TableReference(stmt.source)
				join_type:     .left
				right_table:   &TableReference(TablePrimary{
					body:        stmt.table_name
					correlation: Correlation{
						name: stmt.correlation_name
					}
				})
				specification: stmt.condition
			}
		}
	}, params, mut conn, false)
}

// resolve finds the target table and its columns, the source, and the names in
// the search condition of each clause, so that a name that doesn't exist is an
// error when it's prepared.
fn (stmt MergeStatement) resolve(params map[string]Value, mut conn Connection) ! {
	table := conn.resolved_table(stmt.table_name)!
	for clause in stmt.clauses {
		for set in clause.set {
			table.column(set.column_name)!
		}
		for column in clause.columns {
			table.column(column.sub_entity_name)!
		}
	}
	_, tables := stmt.plan(params, mut conn)!
	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}
	for clause in stmt.clauses {
		if condition := clause.condition {
			condition.compile(mut c)!
		}
	}
}

// check_columns returns an error when a generated column, or a GENERATED ALWAYS
// identity column, is given a value other than DEFAULT, which is only allowed
// for the identity column of an INSERT with an <override clause>, or when an
// INSERT doesn't have one value for each column. These don't depend on the rows
// (they're Syntax Rules), so they're checked before any are read.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Syntax Rules, 13, 14, 20.b and 20.d
// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>, Syntax Rules, 5
fn (stmt MergeStatement) check_columns(table Table) ! {
	for clause in stmt.clauses {
		if clause.matched {
			for set in clause.set {
				if table.column(set.column_name)!.is_generated_always() && !is_default_update(set.source) {
					return sqlstate_428c9(set.column_name)
				}
			}
			continue
		}

		columns := clause.insert_columns(table)
		clause.insert_statement(stmt.table_name).check_override_clause(table, columns)!
		check_insert_degree(columns.len, clause.values.len)!
		for i, column in columns {
			table_column := table.column(column.sub_entity_name)!
			mut always := table_column.generated != none
			if identity := table_column.identity {
				always = identity.always && clause.overriding == ''
			}
			if always && !is_default_specification(clause.values[i]) {
				return sqlstate_428c9(column.sub_entity_name)
			}
		}
	}
}

// is_default_update is true when the value of a <set clause> is DEFAULT.
fn is_default_update(source UpdateSource) bool {
	return if source is ContextuallyTypedValueSpecification {
		source is DefaultSpecification
	} else {
		false
	}
}

fn (stmt MergeStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	stmt.check()!

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())

	stmt.check_columns(table)!

	// The source (and the target row each of its rows matches) is read before
	// any row is changed.
	//
	// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 5
	mut plan, tables := stmt.plan(params, mut conn)!
	rows := plan.execute([]Row{})!

	target_id := if stmt.correlation_name.sub_entity_name != '' {
		stmt.correlation_name.id()
	} else {
		table_name.id()
	}
	mut source_tables := tables.clone()
	source_tables.delete(target_id)
	mut ctx := MergeContext{
		table:         table
		target_id:     target_id
		tables:        tables
		source_tables: source_tables
		params:        params
		check:         new_check_constraints(mut conn, table)!
		generated:     new_generated_columns(mut conn, table)!
	}

	// Each change is worked out before any of them are made, so the rows that
	// are inserted can't be matched, and every value sees the table as it was.
	//
	// A row of the target is the subject row of the first <merge when matched
	// clause> whose search condition is true for a row of the source that it
	// matches. That row of the source is its matching row, and there can only
	// be one for that clause.
	//
	// A row of the source that doesn't match any row of the target is inserted by
	// the first <merge when not matched clause> whose search condition is true.
	// It can reference the target, which is all NULLs. (The rows of S3 are found
	// by joining with the target, which seems to mean the search condition
	// isn't used when the target has no rows, but it is here, as it is in other
	// databases.)
	//
	// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 6.a.i.1, 6.a.ii.1-6
	mut subjects := map[string]MergeSubject{}
	mut order := []string{}
	mut inserts := []Row{}
	for row in rows {
		conn.begin_row()
		n := ctx.first_clause(mut conn, stmt.clauses, row)!
		if n < 0 {
			continue
		}
		clause := stmt.clauses[n]
		if !clause.matched {
			inserts << ctx.insert(mut conn, row, stmt.table_name, clause)!
			continue
		}

		key := row.id.bytestr()
		if subject := subjects[key] {
			if n == subject.clause {
				subjects[key] = MergeSubject{
					...subject
					matches: subject.matches + 1
				}
			} else if n < subject.clause {
				subjects[key] = MergeSubject{n, row, 1}
			}
		} else {
			subjects[key] = MergeSubject{n, row, 1}
			order << key
		}
	}

	// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 6.a.i.1.B.II
	mut subject_rows := []Row{}
	mut changes := []RowChange{}
	for key in order {
		subject := subjects[key] or { return error('no subject') }
		if subject.matches > 1 {
			return sqlstate_21000('more than one row of the source matches the same row of ${table.name}')
		}
		subject_rows << subject.row
		change, did_modify := ctx.update(mut conn, subject.row, subject.clause, stmt.clauses[subject.clause])!
		if did_modify {
			changes << change
		}
	}

	// Each subject row is replaced by its new row, like an UPDATE (a row that
	// gets a new key is deleted first, and added back once the other rows have
	// been replaced), and then the new rows are inserted. The constraints are
	// checked once every row has been written.
	//
	// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 6.a.i.5, 6.a.ii.8
	mut moved := []Row{}
	for change in changes {
		mut before := change.old
		mut after := change.new
		if before.object_key(table)! != after.object_key(table)! {
			catalog.storage.delete_row(table_name.storage_id(), mut before)!
			moved << after
		} else {
			catalog.storage.update_row(before, mut after, table)!
		}
	}
	for mut row in moved {
		catalog.storage.write_row(mut row, table)!
	}
	for mut row in inserts {
		catalog.storage.write_row(mut row, table)!
	}
	apply_referential_actions(mut conn, mut catalog.storage, table, changes)!
	catalog.storage.check_unique_indexes(table, inserts)!
	catalog.storage.check_unique_constraints(table, inserts)!
	catalog.storage.check_foreign_keys(mut conn, table, inserts)!
	conn.note_row_changes(table, subject_rows, changes, none)!

	// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 7
	if rows.len == 0 {
		conn.add_warning(sqlstate_02000())
	}

	// The count is every row that was updated (even if its values didn't
	// change) or inserted.
	//
	// ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 2.f.iii
	return new_result_msg('MERGE ${subject_rows.len + inserts.len}', elapsed_parse, t.elapsed())
}

// update returns the target row of row (a row of the source and the target
// row that it matched), and its candidate new row with the value of each <set
// clause>, which can reference both the source and the target. It's false when
// none of the values changed.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 6.a.i.1.B.III
// ISO/IEC 9075-2:2016(E), 14.15, <set clause list>, General Rules, 2.b
fn (mut ctx MergeContext) update(mut conn Connection, row Row, n int, clause MergeWhenClause) !(RowChange, bool) {
	mut before := Row{
		id:  row.id
		tid: row.tid
	}
	for column in ctx.table.columns {
		before.data.set(column.name.sub_entity_name, row.data.value('${ctx.target_id}.${column.name.sub_entity_name}'))
	}
	mut after := Row{
		id:   row.id
		tid:  row.tid
		data: before.data.clone()
	}

	mut c := Compiler{
		conn:   conn
		params: ctx.params
		tables: ctx.tables
	}
	mut did_modify := false
	for i, set in clause.set {
		column := ctx.table.column(set.column_name)!

		// A generated column is set once the other columns are known (see
		// GeneratedColumns.apply).
		if column.generated != none {
			continue
		}

		c.null_type = column.typ
		c.default_value = column.default_value
		c.identity = identity_of(ctx.table, column)
		key := '${n}.${i}'
		if key !in ctx.compiled {
			ctx.compiled[key] = set.source.compile(mut c)!
		}
		raw_value := ctx.compiled[key] or { return error('not compiled') }.run(mut conn,
			row, ctx.params)!
		if column.not_null && raw_value.is_null {
			return sqlstate_23502(ctx.table, set.column_name)
		}
		check_store_assignment(raw_value, column.typ)!

		// Like an UPDATE, a NULL that stays NULL isn't a change.
		old_value := before.data.value(set.column_name)
		if old_value.is_null && raw_value.is_null {
			continue
		}
		if compare(conn, old_value, raw_value)! != .is_equal {
			did_modify = true
			after.data.set(set.column_name, cast(mut conn, 'for column ${set.column_name}',
				raw_value, column.typ)!)
		}
	}

	// A row that doesn't change isn't written, but it's still counted.
	if !did_modify {
		return RowChange{}, false
	}

	ctx.generated.apply(mut conn, mut after)!
	ctx.check.verify(mut conn, after)!

	return RowChange{
		old: before
		new: after
	}, true
}

// insert returns the new row of a <merge when not matched clause> for a row of
// the source that didn't match a row of the target. Its values can only
// reference the source.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Syntax Rules, 9 and 20
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, General Rules, 6.a.ii.7
fn (ctx MergeContext) insert(mut conn Connection, row Row, table_name Identifier, clause MergeWhenClause) !Row {
	insert := clause.insert_statement(table_name)
	mut inserted := new_row(insert.insert_row(mut conn, ctx.params, ctx.table, clause.insert_columns(ctx.table),
		clause.values, ctx.source_tables, row)!)
	ctx.generated.apply(mut conn, mut inserted)!
	ctx.check.verify(mut conn, inserted)!

	return inserted
}

// insert_statement is the INSERT of a <merge when not matched clause>, for its
// rules.
fn (clause MergeWhenClause) insert_statement(table_name Identifier) InsertStatement {
	return InsertStatement{
		table_name: table_name
		columns:    clause.columns
		overriding: clause.overriding
	}
}

// insert_columns are the columns of a <merge insert specification>, which are
// all of the columns of the table without an <insert column list>.
//
// ISO/IEC 9075-2:2016(E), 14.12, <merge statement>, Syntax Rules, 13
fn (clause MergeWhenClause) insert_columns(table Table) []Identifier {
	if clause.columns.len > 0 {
		return clause.columns
	}

	return table.columns.map(it.name)
}

fn (stmt MergeStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut plan, _ := stmt.plan(params, mut conn)!

	return plan.explain(elapsed_parse)
}
