module vsql

import time

// ISO/IEC 9075-2:2016(E), 7.17, <query expression>
//
// Specify a table.

struct QueryExpression {
	body   SimpleTable
	fetch  ?ValueSpecification
	offset ?ValueSpecification
	order  []SortSpecification
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

	if offset := e.offset {
		s += ' OFFSET ${offset.pstr(params)} ROWS'
	}

	if fetch := e.fetch {
		s += ' FETCH FIRST ${fetch.pstr(params)} ROWS ONLY'
	}

	return s
}

// SetOperation is "<left> UNION <right>" or "<left> EXCEPT <right>". Each side
// is a reference because it can contain another SetOperation, and V stores a
// sum type's value inline.
struct SetOperation {
	left  &QueryExpression
	op    string // UNION or EXCEPT
	all   bool   // DISTINCT is the default (Syntax Rule 6).
	right &QueryExpression
}

fn (e SetOperation) pstr(params map[string]Value) string {
	op := if e.all { '${e.op} ALL' } else { e.op }

	// A set operation is left associative, so one on the right must have been in
	// parentheses.
	right := if e.right.body is SetOperation {
		'(${e.right.pstr(params)})'
	} else {
		e.right.pstr(params)
	}

	return '${e.left.pstr(params)} ${op} ${right}'
}

fn new_set_operation(left SimpleTable, op string, all bool, right SimpleTable) SimpleTable {
	return SimpleTable(SetOperation{
		left:  &QueryExpression{
			body: left
		}
		op:    op
		all:   all
		right: &QueryExpression{
			body: right
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
	tables  map[string]Table
mut:
	conn &Connection
}

fn new_order_operation(order []SortSpecification, params map[string]Value, conn &Connection, columns Columns, tables map[string]Table) &OrderOperation {
	return &OrderOperation{order, params, columns, tables, conn}
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
	return o.columns
}

fn (mut o OrderOperation) execute(rows []Row) ![]Row {
	// TODO(elliotchance): I know this is a horribly inefficient way to handle
	//  sorting. I did it this way because at the time V didn't allow closures
	//  on M1 macs (which would be required to pass in a sort function).
	//  Definitely improve this in the future, especially since sorting of the
	//  top N rows can usually be done much more efficiently than sorting the
	//  whole set.

	// This sorting implementation uses a linked list which is very simple but
	// very expensive at O(n^2).

	mut head := &RowLink(unsafe { nil })
	for row in rows {
		// First item is assigned to head.
		if unsafe { head == 0 } {
			head = &RowLink{
				row: row
			}
			continue
		}

		// If the item is less than the head we unshift it. This cannot be
		// easily done in the next step without us needing to keep the previous
		// pointer as well.
		head_cmp := row_cmp(mut o.conn, o.params, o.tables, row, head.row, o.order)!
		if head_cmp < 0 {
			head = &RowLink{
				row:  row
				next: head
			}
			continue
		}

		// Find the place to insert.
		mut cursor := head
		mut inserted := false
		for unsafe { cursor.next != 0 } {
			cmp := row_cmp(mut o.conn, o.params, o.tables, row, cursor.next.row,
				o.order)!
			if cmp < 0 {
				cursor.next = &RowLink{
					row:  row
					next: cursor.next
				}
				inserted = true
				break
			}
			cursor = cursor.next
		}

		// Or, add it to the tail.
		if !inserted {
			cursor.next = &RowLink{
				row: row
			}
		}
	}

	if unsafe { head == 0 } {
		return []Row{}
	}

	return head.rows()
}

@[heap]
struct RowLink {
	row Row
mut:
	next &RowLink = unsafe { 0 }
}

fn (l &RowLink) rows() []Row {
	mut rows := []Row{}
	mut cursor := unsafe { l }

	for unsafe { cursor.next != 0 } {
		rows << cursor.row
		cursor = cursor.next
	}

	rows << cursor.row

	return rows
}

fn row_cmp(mut conn Connection, params map[string]Value, tables map[string]Table, r1 Row, r2 Row, specs []SortSpecification) !int {
	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}

	// ISO/IEC 9075-2:2016(E), 10.10, <sort specification list>:
	//
	// General Rules
	//
	// 1) A <sort specification list> defines an ordering of rows, as follows:
	//
	//    a) Let N be the number of <sort specification>s.
	//
	//    b) Let Ki, 1 (one) ≤ i ≤ N, be the <sort key> contained in the i-th
	//       <sort specification>.
	//
	//    c) Each <sort specification> specifies the sort direction for the
	//       corresponding sort key Ki. If DESC is not specified in the i-th
	//       <sort specification>, then the sort direction for Ki is ascending and
	//       the applicable <comp op> is the <less than operator>. Otherwise, the
	//       sort direction for Ki is descending and the applicable <comp op> is
	//       the <greater than operator>.
	//
	//    d) Let P be any row of the collection of rows to be ordered, and let Q
	//       be any other row of the same collection of rows.
	//
	//    e) Let PVi and QVi be the values of Ki in P and Q, respectively. The
	//       relative position of rows P and Q in the result is determined by
	//       comparing PVi and QVi as follows:
	//
	//       i) The comparison is performed according to the General Rules of
	//
	//          Case:
	//
	//          1) If the declared type of Ki is a row type, then this Subclause,
	//             applied recursively.
	//          2) Otherwise, Subclause 8.2, “<comparison predicate>”, where the
	//             <comp op> is the applicable <comp op> for Ki.
	//
	//       ii) The comparison is performed with the following special treatment
	//           of null values.
	//
	//           Case:
	//
	//           1) If PVi and QVi are both the null value, then they are
	//              considered equal to each other.
	//           2) If PVi is the null value and QVi is not the null value, then
	//
	//              Case:
	//
	//              A) If NULLS FIRST is specified or implied, then PVi <comp op>
	//                 QVi is considered to be True.
	//              B) If NULLS LAST is specified or implied, then PVi <comp op>
	//                 QVi is considered to be False.
	//
	//           3) If PVi is not the null value and QVi is the null value, then
	//
	//              Case:
	//
	//              A) If NULLS FIRST is specified or implied, then PVi <comp op>
	//                 QVi is considered to be False.
	//              B) If NULLS LAST is specified or implied, then PVi <comp op>
	//                 QVi is considered to be True.
	//
	//    f) PVi is said to precede QVi if the value of the <comparison predicate>
	//       “PVi <comp op> QVi” is True for the applicable <comp op>.
	//
	//    g) If PVi and QVi are not the null value and the result of
	//       “PVi <comp op> QVi” is Unknown, then the relative ordering of PVi and
	//       QVi is implementation-dependent.
	//
	//    h) The relative position of row P is before row Q if PVn precedes QVn
	//       for some n, 1 (one) ≤ n ≤ N, and PVi is not distinct from QVi for all
	//       i < n.
	//
	//    i) Two rows that are not distinct with respect to the
	//       <sort specification>s are said to be peers of each other. The
	//       relative ordering of peers is implementation-dependent.
	for spec in specs {
		left := spec.expr.compile(mut c)!.run(mut conn, r1, params)!
		right := spec.expr.compile(mut c)!.run(mut conn, r2, params)!

		if left.is_null && right.is_null {
			continue
		}

		if left.is_null && !right.is_null {
			return if spec.is_asc { -1 } else { 1 }
		}

		if !left.is_null && right.is_null {
			return if spec.is_asc { 1 } else { -1 }
		}

		cmp := compare(conn, left, right)!
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
	fetch   ?ValueSpecification
	offset  ?ValueSpecification
	params  map[string]Value
	columns Columns
mut:
	conn &Connection
}

fn new_limit_operation(fetch ?ValueSpecification, offset ?ValueSpecification, params map[string]Value, mut conn Connection, columns Columns) &LimitOperation {
	return &LimitOperation{fetch, offset, params, columns, conn}
}

fn (o &LimitOperation) str() string {
	mut s := ''

	if offset := o.offset {
		s = 'OFFSET ${offset.pstr(o.params)} ROWS'
	}

	if fetch := o.fetch {
		s += ' FETCH FIRST ${fetch.pstr(o.params)} ROWS ONLY'
	}

	return s.trim_space()
}

fn (o &LimitOperation) columns() Columns {
	// Limit doesn't change the columns so just pass through from the last
	// operation.
	return o.columns
}

fn (mut o LimitOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
	}
	mut offset := i64(0)
	if off := o.offset {
		offset = row_count('OFFSET', off.compile(mut c)!.run(mut o.conn, Row{}, o.params)!)!

		// General Rule 6b: The offset must not be negative.
		if offset < 0 {
			return sqlstate_2201x()
		}

		if offset >= rows.len {
			return []Row{}
		}
	}

	mut fetch := i64(rows.len)
	if f := o.fetch {
		fetch = row_count('FETCH FIRST', f.compile(mut c)!.run(mut o.conn, Row{}, o.params)!)!

		// General Rule 7c: At least one row must be fetched.
		if fetch < 1 {
			return sqlstate_2201w()
		}
	}

	if fetch >= rows.len - offset {
		fetch = rows.len - offset
	}

	return rows[offset..offset + fetch]
}

// row_count returns the value of an <offset row count> or <fetch first row
// count>. Syntax Rules 29 and 30 require both to be an exact numeric with scale
// 0.
fn row_count(clause string, value Value) !i64 {
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
		return sqlstate_42601('${clause} row count must be an exact numeric with scale 0, got ${value.typ}')
	}

	return value.as_int()
}

// A SetOperationOperation combines the rows of two queries for UNION or EXCEPT.
// Each column has the combined type of that column in both queries (9.5), and
// the name of that column in the left query.
//
// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 16b and 19b
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
		columns << Column{
			name: column.name
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
	return o.columns
}

// execute follows General Rule 3b of 7.17. A row R that appears m times on the
// left and n times on the right appears in the result:
//
//   UNION ALL:       m + n times
//   UNION DISTINCT:  once, if m > 0 or n > 0
//   EXCEPT ALL:      max(m - n, 0) times
//   EXCEPT DISTINCT: once, if m > 0 and n = 0
//
// Rows are duplicates when every value is equal, where NULLs are equal to each
// other (4.1.5).
fn (mut o SetOperationOperation) execute(_ []Row) ![]Row {
	left := o.values(o.left.execute([]Row{})!, o.left.columns())!
	right := o.values(o.right.execute([]Row{})!, o.right.columns())!

	mut kept := [][]Value{}
	if o.op == 'UNION' {
		for values in left {
			if o.all || find_duplicate_row(o.conn, kept, values)! < 0 {
				kept << values
			}
		}
		for values in right {
			if o.all || find_duplicate_row(o.conn, kept, values)! < 0 {
				kept << values
			}
		}
	} else {
		// Each row on the right removes one duplicate from the left for EXCEPT
		// ALL, or every duplicate for EXCEPT DISTINCT.
		mut removed := []bool{len: right.len}
		for values in left {
			if !o.all && find_duplicate_row(o.conn, kept, values)! >= 0 {
				continue
			}

			mut is_removed := false
			for j, other in right {
				if !removed[j] && is_duplicate_row(o.conn, values, other)! {
					removed[j] = o.all
					is_removed = true
					break
				}
			}

			if !is_removed {
				kept << values
			}
		}
	}

	mut rows := []Row{}
	for values in kept {
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

// find_duplicate_row returns the index of the first row that is a duplicate of
// values, or -1.
fn find_duplicate_row(conn &Connection, rows [][]Value, values []Value) !int {
	for i, row in rows {
		if is_duplicate_row(conn, row, values)! {
			return i
		}
	}

	return -1
}
