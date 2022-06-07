// order.v contains operations for handing ORDER BY operations.

module vsql

struct OrderOperation {
	order   []SortSpecification
	params  map[string]Value
	conn    &Connection
	columns Columns
}

fn new_order_operation(order []SortSpecification, params map[string]Value, conn &Connection, columns Columns) &OrderOperation {
	return &OrderOperation{order, params, conn, columns}
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

fn (o &OrderOperation) execute(rows []Row) ?[]Row {
	// TODO(elliotchance): I know this is a horribly inefficient way to handle
	//  sorting. I did it this way because at the time V didn't allow closures
	//  on M1 macs (which would be required to pass in a sort function).
	//  Definitely improve this in the future, especially since sorting of the
	//  top N rows can usually be done must more efficiently than sorting the
	//  whole set.

	// This sorting implementation uses a linked list which is very simple but
	// very expensive at O(n^2).

	mut head := &RowLink(0)
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
		head_cmp := row_cmp(o.conn, o.params, row, head.row, o.order)?
		if head_cmp < 0 {
			head = &RowLink{
				row: row
				next: head
			}
			continue
		}

		// Find the place to insert.
		mut cursor := head
		mut inserted := false
		for unsafe { cursor.next != 0 } {
			cmp := row_cmp(o.conn, o.params, row, cursor.next.row, o.order)?
			if cmp < 0 {
				cursor.next = &RowLink{
					row: row
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

	return head.rows()
}

[heap]
struct RowLink {
	row Row
mut:
	next &RowLink = 0
}

fn (l &RowLink) rows() []Row {
	mut rows := []Row{}
	mut cursor := l
	for unsafe { cursor.next != 0 } {
		rows << cursor.row
		cursor = cursor.next
	}

	rows << cursor.row

	return rows
}

fn row_cmp(conn &Connection, params map[string]Value, r1 Row, r2 Row, specs []SortSpecification) ?int {
	for spec in specs {
		left := eval_as_value(conn, r1, spec.expr, params)?
		right := eval_as_value(conn, r2, spec.expr, params)?

		cmp, _ := left.cmp(right)?
		if cmp != 0 {
			if !spec.is_asc {
				return -cmp
			}

			return cmp
		}
	}

	return 0
}
