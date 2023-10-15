// walk.v contains the iterator that is able to walk through ranges of the
// B-tree.

module vsql

struct PageIterator {
	// min and max are inclusive.
	min []u8
	max []u8
mut:
	btree Btree
	// objects is just for performance so we dont need to parse the objects in
	// the page several times while we iterate that page.
	objects []PageObject
	// path describes the depth. At each depth is an iterator for that page.
	path           []int
	depth_iterator []int
}

fn (mut iter PageIterator) next() ?PageObject {
	// Special case for no data.
	if iter.btree.pager.total_pages() == 0 {
		return none
	}

	// On the first iteration we fast-forward to the starting page.
	if iter.path.len == 0 {
		iter.path, iter.depth_iterator = iter.btree.search_page(iter.min) or { return none }

		// search_page does not include the last depth_iterator becuase that
		// belongs to the leaf not which is does not search.
		iter.depth_iterator << 0

		// Load all the objects for this leaf. Making sure to skip over any keys
		// that are out of bounds.
		iter.objects = (iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or { return none }).objects()
		for object in iter.objects {
			// TODO(elliotchance): It would be more efficient to do a binary
			//  search here since the page is already sorted.
			if compare_bytes(object.key, iter.min) < 0 {
				iter.depth_iterator[iter.depth_iterator.len - 1]++
			}
		}
	}

	// If this page is done, roll up to the parent and continue to traverse
	// down.
	if iter.depth_iterator[iter.depth_iterator.len - 1] >= iter.objects.len {
		for {
			if iter.path.len == 1 {
				return none
			}

			iter.path = iter.path[..iter.path.len - 1]
			iter.depth_iterator = iter.depth_iterator[..iter.depth_iterator.len - 1]
			iter.depth_iterator[iter.depth_iterator.len - 1]++

			if iter.depth_iterator[iter.depth_iterator.len - 1] < (iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or {
				return none
			}).objects().len {
				break
			}
		}

		for (iter.btree.pager.fetch_page(iter.path[iter.path.len - 1])!).kind == kind_not_leaf {
			objects := (iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or { return none }).objects()

			mut buf := new_bytes(objects[iter.depth_iterator[iter.depth_iterator.len - 1]].value)
			iter.path << buf.read_i32()
			iter.depth_iterator << 0
		}

		iter.objects = (iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or { return none }).objects()
	}

	o := iter.objects[iter.depth_iterator[iter.depth_iterator.len - 1]]
	iter.depth_iterator[iter.depth_iterator.len - 1]++

	// We also need to bail out if we encounter a value greater the upper bound.
	if compare_bytes(o.key, iter.max) > 0 {
		return none
	}

	return o
}

// A PrimaryKeyOperation scans an inclusive range for a PRIMARY KEY.
struct PrimaryKeyOperation {
	table  Table
	lower  Expr
	upper  Expr
	params map[string]Value
mut:
	conn &Connection
}

fn new_primary_key_operation(table Table, lower Expr, upper Expr, params map[string]Value, conn &Connection) &PrimaryKeyOperation {
	return &PrimaryKeyOperation{table, lower, upper, params, conn}
}

fn (o &PrimaryKeyOperation) str() string {
	return 'PRIMARY KEY ${o.table.name} (${o.pretty_columns()}) BETWEEN ${o.lower.pstr(o.params)} AND ${o.upper.pstr(o.params)}'
}

// We could just render columns(), however, it makes the output extra verbose,
// so we only show the column names.
fn (o &PrimaryKeyOperation) pretty_columns() Columns {
	mut cols := []Column{}
	for c in o.table.columns {
		cols << Column{Identifier{
			sub_entity_name: c.name.sub_entity_name
		}, c.typ, c.not_null}
	}

	return cols
}

fn (o &PrimaryKeyOperation) columns() Columns {
	mut columns := []Column{}

	for column in o.table.columns {
		columns << Column{column.name, column.typ, column.not_null}
	}

	return columns
}

fn (mut o PrimaryKeyOperation) execute(_ []Row) ![]Row {
	mut lower := eval_as_value(mut o.conn, Row{}, o.lower, o.params)!

	// Literals will be a NUMERIC, so that needs to be cast to the expected type.
	lower = cast(mut o.conn, '', lower, Type{.is_bigint, 0, 0, false})!

	mut tmp_row := Row{
		data: {
			o.table.primary_key[0]: lower
		}
	}
	object_key := tmp_row.object_key(o.table)!

	mut catalog := o.conn.catalog()
	tid := catalog.storage.transaction_id
	mut transaction_ids := catalog.storage.header.active_transaction_ids

	mut rows := []Row{}
	for object in catalog.storage.btree.new_range_iterator(object_key, object_key) {
		if object_is_visible(object.tid, object.xid, tid, mut transaction_ids) {
			rows << new_row_from_bytes(o.table, object.value, object.tid)
		}
	}

	return rows
}
