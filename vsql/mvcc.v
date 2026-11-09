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

fn (mut t TransactionIDs) exists(transaction_id u64) bool {
	for i in 0 .. t.end {
		if t.tids[i] == transaction_id {
			return true
		}
	}

	return false
}

fn object_is_visible(object_tid u64, object_xid u64, current_tid u64, mut active_tids TransactionIDs) bool {
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
