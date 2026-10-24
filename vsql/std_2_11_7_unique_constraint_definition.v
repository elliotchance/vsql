module vsql

// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>
//
// Specify a uniqueness constraint for a table.

struct UniqueConstraintDefinition {
	columns []Identifier
}

// check_primary_key returns an error if a row with the same PRIMARY KEY as r
// already exists in t, or might exist once another transaction finishes. It
// must be called from inside an isolation block.
fn (mut f Storage) check_primary_key(mut r Row, t Table) ! {
	if t.primary_key.len == 0 {
		return
	}

	key := r.object_key(t)!
	mut iter := f.btree.new_range_iterator(key, key)
	for {
		object := iter.next() or { break }
		// Another transaction is creating or deleting a row with this key, so
		// it may or may not exist when that transaction finishes.
		if (object.tid != f.transaction_id && f.header.active_transaction_ids.exists(object.tid))
			|| (object.xid != 0 && object.xid != f.transaction_id
				&& f.header.active_transaction_ids.exists(object.xid)) {
			return sqlstate_40001('avoiding concurrent write on individual row')
		}

		// Otherwise, the row exists unless it was deleted (by this or a
		// committed transaction).
		if object.xid == 0 {
			return sqlstate_23505('PRIMARY KEY on ${t.name}')
		}
	}
	if err := iter.err {
		return err
	}
}
