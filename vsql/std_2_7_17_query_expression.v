module vsql

import math
import time

// ISO/IEC 9075-2:2023, 7.17, <query expression>
//
// Specify a table.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.17.3, Derived tables

struct QueryExpression {
	body   SimpleTable
	fetch  ?FetchFirstClause
	offset ?ValueSpecification
	order  []SortSpecification
	// updatability is the <updatability clause> of a <dynamic select statement>
	// (see cursor_specification), which is only used when it's opened as a
	// cursor (see PreparedStmt.open_cursor). It's always none for any other
	// query, including a subquery.
	updatability ?UpdatabilityClause
}

fn (e QueryExpression) pstr(params map[string]Value) string {
	mut s := e.body.pstr(params)

	if e.order.len > 0 {
		mut specs := []string{}
		for spec in e.order {
			specs << spec.pstr(params)
		}
		s += ' ORDER BY ${specs.join(', ')}'
	}

	if offset := opt_copy(e.offset) {
		s += ' OFFSET ${offset.pstr(params)} ROWS'
	}

	if fetch := opt_copy(e.fetch) {
		s += ' ${fetch.pstr(params)}'
	}

	return s
}

// FetchFirstClause is a <fetch first clause>, or a LIMIT. count is the <fetch
// first row count>, or the <fetch first percentage> when percent is true.
// with_ties also keeps the rows after the last one that are its peers in the
// ORDER BY.
struct FetchFirstClause {
	count     ValueSpecification
	percent   bool
	with_ties bool
}

fn (e FetchFirstClause) pstr(params map[string]Value) string {
	percent := if e.percent { ' PERCENT' } else { '' }
	ending := if e.with_ties { 'WITH TIES' } else { 'ONLY' }

	return 'FETCH FIRST ${e.count.pstr(params)}${percent} ROWS ${ending}'
}

// QuerySetOperator is the UNION, EXCEPT or INTERSECT of a SetOperation.
struct QuerySetOperator {
	op  string
	all bool
}

// SetOperation is "<left> UNION <right>", "<left> EXCEPT <right>" or
// "<left> INTERSECT <right>". Each side is a reference because it can contain
// another SetOperation, and V stores a sum type's value inline.
struct SetOperation {
	left  &QueryExpression
	op    string // UNION, EXCEPT or INTERSECT
	all   bool   // DISTINCT is the default (Syntax Rule 6).
	right &QueryExpression
}

fn (e SetOperation) pstr(params map[string]Value) string {
	// The clone works around https://github.com/vlang/v/issues/32932 (-autofree).
	op := if e.all { '${e.op} ALL' } else { e.op.clone() }

	// A set operation is left associative, so one on the right must have been in
	// parentheses (or is an INTERSECT, where they don't change anything). A UNION
	// or EXCEPT on the left of an INTERSECT must have been in parentheses, since
	// INTERSECT is evaluated first.
	right := if e.right.body is SetOperation {
		'(${e.right.pstr(params)})'
	} else {
		e.right.pstr(params)
	}

	left_body := e.left.body
	left := if e.op == 'INTERSECT' && left_body is SetOperation && left_body.op != 'INTERSECT' {
		'(${e.left.pstr(params)})'
	} else {
		e.left.pstr(params)
	}

	return '${left} ${op} ${right}'
}

fn new_set_operation(left SimpleTable, op string, all bool, right SimpleTable) SimpleTable {
	return SimpleTable(SetOperation{
		left:  &QueryExpression{
			body: own_copy(&left)
		}
		op:    op
		all:   all
		right: &QueryExpression{
			body: own_copy(&right)
		}
	})
}

// ParenthesizedQueryExpression is a <query primary> with its own ORDER BY,
// OFFSET or FETCH FIRST, such as "(SELECT ... FETCH FIRST 1 ROW ONLY) UNION
// ...".
struct ParenthesizedQueryExpression {
	expr &QueryExpression
}

fn (e ParenthesizedQueryExpression) pstr(params map[string]Value) string {
	return '(${e.expr.pstr(params)})'
}

// new_parenthesized_query_expression returns the body of a parenthesized
// <query expression>, unless it needs to be evaluated before an outer ORDER BY,
// OFFSET or FETCH FIRST.
fn new_parenthesized_query_expression(expr QueryExpression) SimpleTable {
	if expr.order.len == 0 && expr.offset == none && expr.fetch == none {
		return expr.body
	}

	return SimpleTable(ParenthesizedQueryExpression{&QueryExpression{
		...expr
	}})
}

// writes must be true if the query modifies the database, see
// PreparedStmt.writes.
fn (stmt QueryExpression) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration, writes bool) !Result {
	t := start_timer()

	if writes {
		conn.open_write_connection()!
	} else {
		conn.open_read_connection()!
	}
	defer {
		if writes {
			conn.release_write_connection()
		} else {
			conn.release_read_connection()
		}
	}

	mut plan := create_plan(stmt, params, mut conn)!

	rows := plan.execute([]Row{})!

	return new_result(plan.columns(), rows, elapsed_parse, t.elapsed())
}

fn (stmt QueryExpression) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut plan := create_plan(stmt, params, mut conn)!

	return plan.explain(elapsed_parse)
}

struct OrderOperation {
	order   []SortSpecification
	params  map[string]Value
	columns Columns
	tables  map[string]&Table
	// result_columns is what a name in a sort key can be, see set_result_columns.
	result_columns map[string][]ValueExpression
mut:
	conn &Connection
}

fn new_order_operation(order []SortSpecification, params map[string]Value, conn &Connection, columns Columns, tables map[string]&Table, result_columns map[string][]ValueExpression) &OrderOperation {
	return &OrderOperation{order, params, columns, tables, result_columns, conn}
}

// set_result_columns sets the columns of the result that a name in an ORDER BY
// can refer to, with the expression of each one. A sort key is evaluated before
// the select list, on the row that it's calculated from, so the name is evaluated
// as that expression. More than one column can have the same name, then the name
// is ambiguous if it's used. The name of an unnamed column is
// implementation-dependent, so it doesn't hide a column of a table.
//
// Without a query specification, the sort keys are only compiled against the
// columns of the result, so the expression is just the name.
//
// ISO/IEC 9075-2:2023, 6.6, <identifier chain>, Syntax Rules, 9.a.i and 9.c
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 26
// set_result_columns is manualfree because each expression is put into
// c.result_columns without a copy, and -autofree frees it with exprs (no small
// repro yet).
@[manualfree]
fn (mut c Compiler) set_result_columns(body SimpleTable, columns Columns) ! {
	mut exprs := columns.map(column_derived_column(Column{
		name: Identifier{
			sub_entity_name: it.name.sub_entity_name
		}
	}))
	if body is QuerySpecification {
		exprs = new_expr_operation(mut c.conn, c.params, body.exprs, c.tables)!.exprs
	}

	c.result_columns = map[string][]ValueExpression{}
	for i, column in columns {
		if !column.unnamed {
			c.result_columns[column.name.sub_entity_name] << exprs[i].expr
		}
	}
}

fn (o &OrderOperation) str() string {
	mut specs := []string{}
	for spec in o.order {
		specs << spec.pstr(o.params)
	}

	return 'ORDER BY ${specs.join(', ')}'
}

fn (o &OrderOperation) columns() Columns {
	// Ordering doesn't change the columns so just pass through from the last
	// operation.
	// The copy works around https://github.com/vlang/v/issues/32932 (-autofree).
	return own_array(o.columns)
}

fn (mut o OrderOperation) execute(rows []Row) ![]Row {
	// A single row doesn't need to be sorted, so its sort keys aren't evaluated.
	if rows.len < 2 {
		return rows
	}

	// Each sort key is compiled once, and evaluated once for each row, rather
	// than for each comparison.
	mut c := Compiler{
		conn:           o.conn
		params:         o.params
		tables:         o.tables
		result_columns: o.result_columns
	}
	mut compiled := []CompileResult{cap: o.order.len}
	for spec in o.order {
		compiled << spec.expr.compile(mut c)!
	}

	mut keys := [][]Value{cap: rows.len}
	for row in rows {
		mut key := []Value{cap: compiled.len}
		for e in compiled {
			key << e.run(mut o.conn, row, o.params)!
		}
		keys << key
	}

	// A merge sort is O(n log n) and stable, so rows that are equal for every
	// sort key (peers) stay in the order they were read in. It sorts the
	// positions of the rows, so an error from a comparison is returned as soon
	// as it happens.
	mut positions := []int{len: rows.len, init: index}
	mut buffer := []int{len: rows.len}
	mut width := 1
	for width < rows.len {
		for lo := 0; lo < rows.len - width; lo += 2 * width {
			mid := lo + width
			hi := if mid + width < rows.len { mid + width } else { rows.len }
			mut i := lo
			mut j := mid
			mut k := lo
			for i < mid && j < hi {
				// Only a row that's strictly less is taken from the right half.
				if sort_keys_cmp(o.conn, keys[positions[j]], keys[positions[i]], o.order)! < 0 {
					buffer[k] = positions[j]
					j++
				} else {
					buffer[k] = positions[i]
					i++
				}
				k++
			}
			for i < mid {
				buffer[k] = positions[i]
				i++
				k++
			}
			for j < hi {
				buffer[k] = positions[j]
				j++
				k++
			}
			for x in lo .. hi {
				positions[x] = buffer[x]
			}
		}
		width *= 2
	}

	return positions.map(rows[it])
}

// sort_keys_cmp compares the values of the sort keys of two rows.
fn sort_keys_cmp(conn &Connection, left []Value, right []Value, specs []SortSpecification) !int {
	// Each sort key is compared in turn, and the first one that isn't equal
	// decides the order of the two rows. The values are compared like a
	// <comparison predicate> with < (or > for DESC). Two null values are equal,
	// and a null value is before every other value for NULLS FIRST, or after
	// them for NULLS LAST, whichever the direction is. The implementation-defined
	// default <null ordering> is NULLS FIRST for ASC and NULLS LAST for DESC
	// (see new_sort_specification). Rows that are equal for every sort key
	// (peers) are in an implementation-dependent order, which is the order they
	// were read in since the merge sort in OrderOperation.execute is stable.
	//
	// ISO/IEC 9075-2:2023, 10.10, <sort specification list>, Syntax Rules, 2 and 3
	// ISO/IEC 9075-2:2023, 10.10, <sort specification list>, General Rules, 1
	for i, spec in specs {
		if left[i].is_null && right[i].is_null {
			continue
		}

		if left[i].is_null && !right[i].is_null {
			return if spec.nulls_first { -1 } else { 1 }
		}

		if !left[i].is_null && right[i].is_null {
			return if spec.nulls_first { 1 } else { -1 }
		}

		cmp := compare(conn, left[i], right[i])!
		if cmp == .is_equal {
			continue
		}

		if cmp == .is_less {
			return if spec.is_asc { -1 } else { 1 }
		}

		return if spec.is_asc { 1 } else { -1 }
	}

	return 0
}

// A LimitOperation stops after a specified number of rows have been received.
// It is also used for OFFSET clauses.
struct LimitOperation {
	fetch   ?FetchFirstClause
	offset  ?ValueSpecification
	params  map[string]Value
	columns Columns
mut:
	conn &Connection
	// order, tables and result_columns are what's needed to evaluate the sort
	// keys of a row (see OrderOperation), to find the peers for WITH TIES.
	order          []SortSpecification
	tables         map[string]&Table
	result_columns map[string][]ValueExpression
}

fn new_limit_operation(fetch ?FetchFirstClause, offset ?ValueSpecification, params map[string]Value, mut conn Connection, columns Columns) &LimitOperation {
	return &LimitOperation{
		fetch:   fetch
		offset:  offset
		params:  params
		columns: columns
		conn:    conn
	}
}

fn (o &LimitOperation) str() string {
	mut s := ''

	if offset := opt_copy(o.offset) {
		s = 'OFFSET ${offset.pstr(o.params)} ROWS'
	}

	if fetch := opt_copy(o.fetch) {
		s += ' ${fetch.pstr(o.params)}'
	}

	return s.trim_space()
}

fn (o &LimitOperation) columns() Columns {
	// Limit doesn't change the columns so just pass through from the last
	// operation.
	// The copy works around https://github.com/vlang/v/issues/32932 (-autofree).
	return own_array(o.columns)
}

fn (mut o LimitOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
	}
	mut offset := i64(0)
	if off := opt_copy(o.offset) {
		offset = row_count('OFFSET', off.compile(mut c)!.run(mut o.conn, Row{}, o.params)!)!

		// General Rule 6b: The offset must not be negative.
		if offset < 0 {
			return sqlstate_2201x()
		}

		if offset >= rows.len {
			return []Row{}
		}
	}

	// The percentage is of all the rows, before any are skipped by OFFSET
	// (General Rules, 7.b.ii).
	mut fetch := i64(rows.len)
	if f := opt_copy(o.fetch) {
		value := f.count.compile(mut c)!.run(mut o.conn, Row{}, o.params)!
		fetch = if f.percent {
			fetch_percentage(value, rows.len)!
		} else {
			row_count('FETCH FIRST', value)!
		}

		// General Rule 7c: At least one row must be fetched.
		if fetch < 1 {
			return sqlstate_2201w()
		}
	}

	if fetch >= rows.len - offset {
		fetch = rows.len - offset
	}

	mut end := int(offset + fetch)
	if f := opt_copy(o.fetch) {
		if f.with_ties && end < rows.len {
			end = o.end_of_peers(rows, end)!
		}
	}

	return rows[offset..end]
}

// end_of_peers returns where the rows that are peers of the last fetched row
// (the one before end) end. The rows are already in the order of the ORDER BY,
// so the peers are the rows straight after it that have the same value for
// every sort key.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 7.d.i
fn (mut o LimitOperation) end_of_peers(rows []Row, end int) !int {
	mut c := Compiler{
		conn:           o.conn
		params:         o.params
		tables:         o.tables
		result_columns: o.result_columns
	}
	mut compiled := []CompileResult{cap: o.order.len}
	for spec in o.order {
		compiled << spec.expr.compile(mut c)!
	}

	last := o.sort_key(compiled, rows[end - 1])!
	mut i := end
	for i < rows.len {
		if sort_keys_cmp(o.conn, o.sort_key(compiled, rows[i])!, last, o.order)! != 0 {
			break
		}
		i++
	}

	return i
}

fn (mut o LimitOperation) sort_key(compiled []CompileResult, row Row) ![]Value {
	mut key := []Value{cap: compiled.len}
	for e in compiled {
		key << e.run(mut o.conn, row, o.params)!
	}

	return key
}

// row_count returns the value of an <offset row count> or <fetch first row
// count>. Syntax Rules 29 and 30 require both to be an exact numeric with scale
// 0.
fn row_count(clause string, value Value) !i64 {
	return exact_integer('${clause} row count', value)
}

// fetch_percentage returns the number of rows for a <fetch first percentage>,
// which is the percentage of total rows, rounded up. It's at most total, so
// that a percentage over 100 doesn't overflow, and it's 0 (an exception for the
// caller) when it's less than 1, including when there are no rows at all.
//
// The product of an exact numeric percentage and the number of rows is exact,
// so that a percentage like 0.07 of 10000 rows is 7 rows, not 8.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 29
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 7.b.ii
fn fetch_percentage(value Value, total int) !i64 {
	product := match value.typ.typ {
		.is_smallint, .is_integer, .is_bigint, .is_numeric, .is_decimal {
			value.as_numeric()!.multiply(new_numeric_from_string(total.str())).f64()
		}
		.is_real, .is_double_precision {
			value.as_f64()! * total
		}
		else {
			return sqlstate_42601('FETCH FIRST percentage must be numeric, got ${value.typ}')
		}
	}

	return i64(math.min(math.max(math.ceil(product / 100.0), 0), total))
}

// exact_integer returns the value, which must be an exact numeric with scale 0
// (what is the name of the value for the error).
fn exact_integer(what string, value Value) !i64 {
	is_valid := match value.typ.typ {
		.is_smallint, .is_integer, .is_bigint {
			true
		}
		.is_numeric, .is_decimal {
			value.typ.scale == 0
		}
		else {
			false
		}
	}

	if !is_valid {
		return sqlstate_42601('${what} must be an exact numeric with scale 0, got ${value.typ}')
	}

	return value.as_int()
}

// A SetOperationOperation combines the rows of two queries for UNION, EXCEPT or
// INTERSECT. Each column has the combined type of that column in both queries
// (9.5), and the name of that column in the left query.
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, Syntax Rules, 16.b, 18 and 19.b
struct SetOperationOperation {
	op      string
	all     bool
	columns Columns
mut:
	conn  &Connection
	left  Plan
	right Plan
}

fn new_set_operation_operation(op SetOperation, left Plan, right Plan, mut conn Connection) !&SetOperationOperation {
	left_columns := left.columns()
	right_columns := right.columns()
	if left_columns.len != right_columns.len {
		return sqlstate_42601('each ${op.op} query must have the same number of columns')
	}

	mut columns := []Column{}
	for i, column in left_columns {
		typ := combine_types(column.typ, right_columns[i].typ) or {
			return sqlstate_42804('in column ${i + 1} of ${op.op}', column.typ.str(),
				right_columns[i].typ.str())
		}
		// UNION ALL keeps every row, but any other set operation is a grouping
		// operation (9.12, Syntax Rules, 1.e-1.g).
		if op.op != 'UNION' || !op.all {
			check_grouping_operand(typ, 'column ${i + 1} of ${op.op}')!
		}
		// A column of "SELECT *" is named by the column it refers to, such as
		// T.A, but the result only has the column name (and the key of a
		// duplicate name, see new_expr_operation), which is what each row of the
		// result is read with (#716).
		// The copies work around https://github.com/vlang/v/issues/32453
		// (-autofree).
		columns << Column{
			name: Identifier{
				custom_id:       own_string(column.name.custom_id)
				sub_entity_name: own_string(column.name.sub_entity_name)
			}
			typ:  typ
		}
	}

	return &SetOperationOperation{op.op, op.all, columns, conn, left, right}
}

fn (o &SetOperationOperation) str() string {
	quantifier := if o.all { 'ALL' } else { 'DISTINCT' }

	return '${o.op} ${quantifier} (${o.columns})'
}

fn (o &SetOperationOperation) columns() Columns {
	// The copy works around https://github.com/vlang/v/issues/32932 (-autofree).
	return own_array(o.columns)
}

// execute combines the rows of both sides. A row R that appears m times on the
// left and n times on the right appears in the result:
//
//   UNION ALL:       m + n times
//   UNION DISTINCT:  once, if m > 0 or n > 0
//   EXCEPT ALL:      max(m - n, 0) times
//   EXCEPT DISTINCT: once, if m > 0 and n = 0
//   INTERSECT ALL:      min(m, n) times
//   INTERSECT DISTINCT: once, if m > 0 and n > 0
//
// Rows are duplicates when every value is equal, where NULLs are equal to each
// other (4.1.5).
//
// ISO/IEC 9075-2:2023, 7.17, <query expression>, General Rules, 3.b
fn (mut o SetOperationOperation) execute(_ []Row) ![]Row {
	left := o.values(o.left.execute([]Row{})!, o.left.columns())!
	right := o.values(o.right.execute([]Row{})!, o.right.columns())!

	mut kept := RowSet{}
	if o.op == 'UNION' {
		for values in left {
			if o.all || kept.find(o.conn, values)! < 0 {
				kept.add(values)
			}
		}
		for values in right {
			if o.all || kept.find(o.conn, values)! < 0 {
				kept.add(values)
			}
		}
	} else {
		// Each left row is matched with a duplicate on the right. For ALL, each
		// row on the right can only be matched once, so it removes one duplicate
		// from the left for EXCEPT, or keeps one for INTERSECT. Otherwise, it
		// removes (or keeps) every duplicate, and only the first one is kept.
		mut right_rows := RowSet{}
		for values in right {
			right_rows.add(values)
		}
		mut matched := []bool{len: right.len}
		for values in left {
			if !o.all && kept.find(o.conn, values)! >= 0 {
				continue
			}

			mut is_matched := false
			for j in right_rows.candidates(values) {
				if !matched[j] && is_duplicate_row(o.conn, values, right[j])! {
					matched[j] = o.all
					is_matched = true
					break
				}
			}

			if is_matched == (o.op == 'INTERSECT') {
				kept.add(values)
			}
		}
	}

	mut rows := []Row{}
	for values in kept.rows {
		mut data := map[string]Value{}
		for i, column in o.columns {
			data[column.name.id()] = values[i]
		}
		rows << new_row(data)
	}

	return rows
}

// values returns the values of each row, cast to the type of each column of the
// result.
fn (mut o SetOperationOperation) values(rows []Row, columns Columns) ![][]Value {
	mut all_values := [][]Value{}
	for row in rows {
		mut values := []Value{}
		for i, column in columns {
			values << convert_to_combined_type(mut o.conn, 'in ${o.op}', row.get_column(column)!,
				o.columns[i].typ)!
		}
		all_values << values
	}

	return all_values
}
