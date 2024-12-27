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
	return '<subquery>'
}

fn (stmt QueryExpression) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
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
mut:
	conn &Connection
}

fn new_order_operation(order []SortSpecification, params map[string]Value, conn &Connection, columns Columns) &OrderOperation {
	return &OrderOperation{order, params, columns, conn}
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
		head_cmp := row_cmp(mut o.conn, o.params, row, head.row, o.order)!
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
			cmp := row_cmp(mut o.conn, o.params, row, cursor.next.row, o.order)!
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

fn row_cmp(mut conn Connection, params map[string]Value, r1 Row, r2 Row, specs []SortSpecification) !int {
	mut c := Compiler{
		conn:   conn
		params: params
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

		cmp := compare(left, right)!
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
		offset = (off.compile(mut c)!.run(mut o.conn, Row{}, o.params)!).as_int()

		if offset >= rows.len {
			return []Row{}
		}
	}

	mut fetch := i64(rows.len)
	if f := o.fetch {
		fetch = (f.compile(mut c)!.run(mut o.conn, Row{}, o.params)!).as_int()
	}

	if offset + fetch >= rows.len {
		fetch = rows.len - offset
	}

	return rows[offset..offset + fetch]
}
