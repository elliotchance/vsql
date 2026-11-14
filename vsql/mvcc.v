// mvcc.v contains the implementation for transactions.

module vsql

// TransactionIDs provides both the storage and mechanisms for a stack of
// transaction IDs.
//
// The 256 slots are stored in the database header - see header.v.
struct TransactionIDs {
mut:
	// tids ensures we reserve up to 256 slots (2kb) for active transaction IDs.
	tids [256]u64
	// end is one more than the last slot in use, so that only the slots before
	// it need to be searched (there's usually only one). It isn't stored, see
	// update_end.
	end int
}

// update_end sets end after tids has been changed directly.
fn (mut t TransactionIDs) update_end() {
	t.end = 256
	for t.end > 0 && t.tids[t.end - 1] == 0 {
		t.end--
	}
}

fn (mut t TransactionIDs) add(transaction_id u64) ! {
	for i in 0 .. 256 {
		if t.tids[i] == 0 {
			t.tids[i] = transaction_id
			if i >= t.end {
				t.end = i + 1
			}
			return
		}
	}

	return sqlstate_0b000('max concurrent transactions reached')
}

fn (mut t TransactionIDs) remove(transaction_id u64) {
	for i in 0 .. t.end {
		if t.tids[i] == transaction_id {
			t.tids[i] = 0
			t.update_end()
			return
		}
	}
}

// has_other returns true if a transaction other than transaction_id is active.
// It's called for every row that's written, so t isn't copied (it's 2 KB) and
// only the slots in use are searched.
fn (t &TransactionIDs) has_other(transaction_id u64) bool {
	for i in 0 .. t.end {
		if t.tids[i] != 0 && t.tids[i] != transaction_id {
			return true
		}
	}

	return false
}

fn (t &TransactionIDs) exists(transaction_id u64) bool {
	for i in 0 .. t.end {
		if t.tids[i] == transaction_id {
			return true
		}
	}

	return false
}

// object_is_visible is whether an object is visible to a statement of
// current_tid (READ COMMITTED), where active_tids are the transactions that are
// active now. A REPEATABLE READ transaction uses its TransactionSnapshot
// instead, see Storage.is_visible.
fn object_is_visible(object_tid u64, object_xid u64, current_tid u64, active_tids &TransactionIDs) bool {
	// The record was created in active transaction that is not our own.
	if active_tids.exists(object_tid) && object_tid != current_tid {
		return false
	}

	// The record is expired or and no transaction holds it that is our own.
	if object_xid != 0 && (!active_tids.exists(object_xid) || object_xid == current_tid) {
		return false
	}

	return true
}

// snapshot_file_format_version is the version of the file format that the first
// REPEATABLE READ transaction raises the Write Version of the file to, because
// an older version of vsql would remove versions of rows that its snapshot
// still needs. See "Compatibility" in the "File Format" docs.
const snapshot_file_format_version = u16(3)

// A TransactionSnapshot is what a REPEATABLE READ transaction can see (snapshot
// isolation): the changes of the transactions that had committed when it
// started, and its own changes. It's kept in memory (the header is read again
// for every statement), see take_snapshot.
//
// That prevents dirty reads, non-repeatable reads and phantoms (as the
// standard describes them, for rows that are read again), but it isn't
// serializable: two transactions can each read rows that the other one
// changes (write skew). REPEATABLE READ allows phantoms, so it doesn't need to
// be, and SERIALIZABLE uses the isolation lock instead (see isolation.v).
//
// ISO/IEC 9075-2:2023(E), 4.43.4, Isolation levels of SQL-transactions
struct TransactionSnapshot {
	// xmax is the ID of the transaction itself. Transactions with a higher ID
	// started after it.
	xmax u64
	// active are the other transactions that were active when it started.
	active []u64
	// xmin is the lowest of active, or xmax. Every transaction before it had
	// finished.
	xmin u64
	// start_schema_version is the Schema Version when it started, and
	// schema_version is the Schema Version after its last change to the
	// schema. See Storage.end_snapshot and Storage.schema_changed.
	start_schema_version int
mut:
	schema_version int
}

fn new_transaction_snapshot(xmax u64, active []u64, schema_version int) TransactionSnapshot {
	mut xmin := xmax
	for tid in active {
		if tid < xmin {
			xmin = tid
		}
	}

	return TransactionSnapshot{
		xmax:                 xmax
		active:               active
		xmin:                 xmin
		start_schema_version: schema_version
		schema_version:       schema_version
	}
}

// new_transaction_snapshot_from_bytes reads the value of a Snapshot Object, see
// TransactionSnapshot.bytes.
fn new_transaction_snapshot_from_bytes(data []u8) TransactionSnapshot {
	mut b := new_bytes(data)
	xmax := b.read_u64()
	mut active := []u64{}
	for b.has_more() {
		active << b.read_u64()
	}

	return new_transaction_snapshot(xmax, active, 0)
}

// bytes is the value of the Snapshot Object of a transaction (see
// take_snapshot): xmax followed by each of active.
fn (s TransactionSnapshot) bytes() []u8 {
	mut b := new_empty_bytes()
	b.write_u64(s.xmax)
	for tid in s.active {
		b.write_u64(tid)
	}

	return b.bytes()
}

// is_committed is true when the transaction had committed when the snapshot
// was taken. A transaction that was rolled back by then doesn't have any
// objects left, so it doesn't matter that it's included.
fn (s &TransactionSnapshot) is_committed(tid u64) bool {
	return tid < s.xmin || (tid < s.xmax && tid !in s.active)
}

// is_visible is object_is_visible for the snapshot.
fn (s &TransactionSnapshot) is_visible(object_tid u64, object_xid u64, current_tid u64) bool {
	if object_tid != current_tid && !s.is_committed(object_tid) {
		return false
	}

	return object_xid == 0 || (object_xid != current_tid && !s.is_committed(object_xid))
}

// is_visible is whether an object is visible to the current transaction.
fn (f &Storage) is_visible(object_tid u64, object_xid u64) bool {
	if f.snapshot_isolation {
		return f.transaction_snapshot.is_visible(object_tid, object_xid, f.transaction_id)
	}

	return object_is_visible(object_tid, object_xid, f.transaction_id, f.header.active_transaction_ids)
}

// snapshot_key is the key of the Snapshot Object of a transaction, see
// take_snapshot.
fn snapshot_key(tid u64) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`P`)
	key.write_u64(tid)

	return key.bytes()
}

// retained_key is the key of the Retained Version Object for a version of key
// that was expired by xid, see remove_expired.
fn retained_key(xid u64, key []u8) []u8 {
	mut buf := new_empty_bytes()
	buf.write_u8(`G`)
	buf.write_u64(xid)
	buf.write_u8s(key)

	return buf.bytes()
}

// take_snapshot must be called when a REPEATABLE READ transaction starts, once
// it has its transaction ID (with the file locked exclusively).
//
// Other transactions can commit while it's active, and COMMIT removes the
// versions of rows that it expired, which the snapshot may still need. So the
// snapshot is published as a Snapshot Object, which every COMMIT checks, see
// remove_expired. It's created by the transaction, so it's removed if the
// process stops (see recover), as well as by end_snapshot.
fn (mut f Storage) take_snapshot() ! {
	f.transaction_snapshot = new_transaction_snapshot(f.transaction_id, f.other_transaction_ids(f.header),
		f.header.schema_version)
	f.snapshot_isolation = true

	// The Write Version is never lowered.
	if f.header.write_version < snapshot_file_format_version {
		f.header.write_version = snapshot_file_format_version
	}

	f.btree.add(new_page_object(snapshot_key(f.transaction_id), f.transaction_id, 0,
		f.transaction_snapshot.bytes()))!
}

// end_snapshot must be called when a REPEATABLE READ transaction commits or
// rolls back. Its Snapshot Object is removed, and so are the versions of rows
// that were only kept for it. It returns true if the schema must be loaded again,
// because it was loaded for the snapshot.
fn (mut f Storage) end_snapshot() !bool {
	if !f.snapshot_isolation {
		return false
	}

	f.delete_object(snapshot_key(f.transaction_id), f.transaction_id)!
	f.snapshot_isolation = false
	f.remove_retained_versions(f.header.active_transaction_ids)!

	return f.header.schema_version != f.transaction_snapshot.start_schema_version
}

// published_snapshots are the snapshots of the active REPEATABLE READ
// transactions, other than exclude.
fn (mut f Storage) published_snapshots(active &TransactionIDs, exclude u64) ![]TransactionSnapshot {
	mut snapshots := []TransactionSnapshot{}

	// Only another active transaction can have a snapshot, so there's no need
	// to read them.
	if !active.has_other(exclude) {
		return snapshots
	}

	for object in f.raw_objects('P'.bytes(), 'Q'.bytes())! {
		mut key := new_bytes(object.key[1..])
		owner := key.read_u64()
		if owner != exclude && active.exists(owner) {
			snapshots << new_transaction_snapshot_from_bytes(object.value)
		}
	}

	return snapshots
}

// raw_objects are all of the objects from start to end (inclusive), whether
// they're visible or not.
fn (mut f Storage) raw_objects(start []u8, end []u8) ![]PageObject {
	mut objects := []PageObject{}
	mut iter := f.btree.new_range_iterator(start, end)
	for {
		object := iter.next() or { break }
		objects << PageObject{
			...object
			key:   object.key.clone()
			value: object.value.clone()
		}
	}
	if err := iter.err {
		return err
	}

	return objects
}

// remove_expired removes the objects on the pages that were expired by the
// transaction that's committing. That's done straight away, rather than leaving
// them for something else to clean up later, so that a row can be changed
// again (there can only be two versions of a key, see Page.add).
//
// Except that an active REPEATABLE READ transaction can still see an object
// that was created by a transaction that had committed when its snapshot was
// taken (this transaction hadn't, since it's committing now). Those are kept,
// with a Retained Version Object, until no snapshot needs them (see
// remove_retained_versions). Until then, another transaction can't change the
// row (it gets a 40001), because there are already two versions.
//
// When check_schema, it returns true if one of the objects the transaction
// created or expired is part of the schema.
fn (mut f Storage) remove_expired(page_numbers []int, check_schema bool) !bool {
	// There's no need to read the snapshots.
	if page_numbers.len == 0 {
		return false
	}

	snapshots := f.published_snapshots(f.header.active_transaction_ids, f.transaction_id)!
	mut blob_refs := []PageObject{}
	mut retained := []PageObject{}
	mut schema_changed := false
	for page_number in page_numbers {
		// A page is only copied and stored again when it has an object to
		// remove, see Pager.read_page.
		page_in_place := f.btree.pager.read_page(page_number)!
		if !f.commit_locked && page_in_place.has_object_of(f.transaction_id) {
			f.lock_commit()!
		}
		schema_changed = schema_changed
			|| (check_schema && page_in_place.has_schema_object_of(f.transaction_id))

		expired := page_in_place.expired_objects(f.transaction_id)
		if expired.len == 0 {
			continue
		}

		mut page := f.btree.pager.fetch_page(page_number)!
		for obj in expired {
			if obj.tid != f.transaction_id && snapshots.any(it.is_committed(obj.tid)) {
				retained << PageObject{
					...obj
					key: obj.key.clone()
				}
				continue
			}

			page.delete(obj.key, obj.tid)
			if obj.is_blob_ref {
				blob_refs << obj
			}
		}

		f.btree.pager.store_page(page_number, page)!
	}

	for obj in blob_refs {
		f.btree.remove_blob(obj)!
	}

	// The objects are only added once the pages have been visited, because
	// adding one can split a page, which would move objects that haven't been
	// removed yet to a page that isn't in page_numbers.
	for obj in retained {
		mut value := new_empty_bytes()
		value.write_u64(obj.tid)
		f.btree.add(new_page_object(retained_key(f.transaction_id, obj.key), f.transaction_id,
			0, value.bytes()))!
	}

	return schema_changed
}

// remove_retained_versions removes the objects that were kept by remove_expired
// that no active snapshot can see anymore, because the transaction that expired
// it had committed when the snapshot was taken, or the one that created it
// hadn't.
fn (mut f Storage) remove_retained_versions(active &TransactionIDs) ! {
	snapshots := f.published_snapshots(active, 0)!
	for object in f.raw_objects('G'.bytes(), 'H'.bytes())! {
		mut key := new_bytes(object.key[1..])
		xid := key.read_u64()
		mut value := new_bytes(object.value)
		tid := value.read_u64()
		if !snapshots.any(it.is_committed(tid) && !it.is_committed(xid)) {
			f.delete_object(object.key[9..], tid)!
			f.delete_object(object.key, object.tid)!
		}
	}
}

// delete_object removes the object with key that was created by tid (and its
// blob, if it has one), if it exists.
fn (mut f Storage) delete_object(key []u8, tid u64) ! {
	path, _ := f.btree.search_page(key)!
	page_number := path.last()
	mut page := f.btree.pager.fetch_page(page_number)!
	obj := page.get(key, tid)
	if obj.key.len == 0 {
		return
	}

	page.delete(key, tid)
	f.btree.pager.store_page(page_number, page)!
	if obj.is_blob_ref {
		f.btree.remove_blob(obj)!
	}
}
