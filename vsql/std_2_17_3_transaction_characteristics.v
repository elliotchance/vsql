module vsql

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>
//
// Specify transaction characteristics.
//
// The <diagnostics size> is the most conditions that are kept in Connection.warnings during the
// SQL-transaction.

// max_conditions is the most conditions that can be kept in Connection.warnings,
// and the number when there isn't a <diagnostics size>.
//
// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 7
const max_conditions = 100

type TransactionMode = DiagnosticsSize | IsolationLevel | TransactionAccessMode

struct DiagnosticsSize {
	number_of_conditions ValueSpecification
}

enum TransactionAccessMode {
	read_only
	read_write
}

// IsolationLevel is the <level of isolation>. An SQL-implementation may use a
// stricter level than the one that is asked for, so READ UNCOMMITTED runs as READ
// COMMITTED. REPEATABLE READ uses snapshot isolation (see
// Storage.take_snapshot). See isolation.v.
//
// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 6
pub enum IsolationLevel {
	read_uncommitted
	read_committed
	repeatable_read
	serializable
}

// locks_transaction is true if the SQL-transaction must hold the isolation lock
// until it ends, so that no other transaction can commit in the meantime.
fn (level IsolationLevel) locks_transaction() bool {
	return level == .serializable
}

fn (level IsolationLevel) str() string {
	return match level {
		.read_uncommitted { 'READ UNCOMMITTED' }
		.read_committed { 'READ COMMITTED' }
		.repeatable_read { 'REPEATABLE READ' }
		.serializable { 'SERIALIZABLE' }
	}
}

// transaction_isolation_level returns the isolation level of the current
// SQL-transaction (or the previous one, if there isn't a current one), such as
// "SERIALIZABLE". It's the level that was asked for, which isn't always how the
// SQL-transaction runs (see the "Transactions" documentation).
pub fn (conn Connection) transaction_isolation_level() string {
	return conn.isolation_level.str()
}

// next_transaction_characteristics returns the <transaction characteristics>
// that a SET TRANSACTION set for the next SQL-transaction, such as
// "ISOLATION LEVEL READ COMMITTED, DIAGNOSTICS SIZE 1", or an empty string if
// there wasn't one. A client that starts each SQL-transaction itself (such as
// libvsql) uses this, so that its START TRANSACTION has them.
pub fn (conn Connection) next_transaction_characteristics() string {
	next := conn.next_transaction or { return '' }
	mut modes := ['ISOLATION LEVEL ${next.isolation_level}']
	// READ UNCOMMITTED is always READ ONLY.
	if next.read_only && next.isolation_level != .read_uncommitted {
		modes << 'READ ONLY'
	}
	if next.condition_area_limit > 0 {
		modes << 'DIAGNOSTICS SIZE ${next.condition_area_limit}'
	}

	return modes.join(', ')
}

// next_diagnostics_size returns the <number of conditions> of the DIAGNOSTICS
// SIZE that a SET TRANSACTION set for the next SQL-transaction, or 0 if there
// wasn't one. libvsql uses this for an SQL-transaction that's started by
// SQLStartTran, which only has an access mode and isolation level.
pub fn (conn Connection) next_diagnostics_size() int {
	next := conn.next_transaction or { return 0 }

	return next.condition_area_limit
}

// transaction_read_only returns true if the current SQL-transaction (or the
// previous one, if there isn't a current one) is READ ONLY.
pub fn (conn Connection) transaction_read_only() bool {
	return conn.read_only
}

// current_characteristics are the characteristics of the current SQL-transaction.
fn (conn Connection) current_characteristics() TransactionCharacteristics {
	return TransactionCharacteristics{
		read_only:            conn.read_only
		isolation_level:      conn.isolation_level
		condition_area_limit: conn.condition_area_limit
	}
}

struct TransactionCharacteristics {
	// read_only is the <transaction access mode>. READ WRITE is the default,
	// except for READ UNCOMMITTED.
	//
	// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 4
	read_only bool
	// isolation_level is SERIALIZABLE when there isn't an <isolation level> (see
	// Connection.enduring_characteristics).
	//
	// ISO/IEC 9075-2:2016(E), 4.41.4, Isolation levels of SQL-transactions
	// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 3
	isolation_level IsolationLevel = .serializable
	// condition_area_limit is the <number of conditions>, or 0 if there isn't a
	// <diagnostics size> (which is max_conditions).
	condition_area_limit int
}

// check_transaction_modes checks that there's at most one of each kind of mode,
// and that READ UNCOMMITTED isn't READ WRITE.
//
// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 2 and 5
fn check_transaction_modes(modes []TransactionMode) ! {
	if modes.filter(it is TransactionAccessMode).len > 1 {
		return sqlstate_42601('transaction access mode is specified more than once')
	}
	if modes.filter(it is IsolationLevel).len > 1 {
		return sqlstate_42601('isolation level is specified more than once')
	}
	if modes.filter(it is DiagnosticsSize).len > 1 {
		return sqlstate_42601('DIAGNOSTICS SIZE can only be used once')
	}
	if modes.any(it is IsolationLevel && it == .read_uncommitted)
		&& modes.any(it is TransactionAccessMode && it == .read_write) {
		return sqlstate_42601('READ WRITE cannot be used with READ UNCOMMITTED')
	}
}

// new_transaction_characteristics returns the characteristics of modes, which
// have been checked by check_transaction_modes.
fn new_transaction_characteristics(mut conn Connection, params map[string]Value, modes []TransactionMode) !TransactionCharacteristics {
	mut read_only := false
	mut isolation_level := conn.default_isolation_level
	mut limit := 0
	for mode in modes {
		match mode {
			TransactionAccessMode {
				read_only = mode == .read_only
			}
			IsolationLevel {
				isolation_level = mode
				conn.check_held_cursors(mode)!
			}
			DiagnosticsSize {
				limit = condition_area_limit(mut conn, params, mode)!
			}
		}
	}

	// READ UNCOMMITTED is always READ ONLY, including when it's the
	// ConnectionOptions.isolation_level.
	//
	// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 4
	if isolation_level == .read_uncommitted {
		read_only = true
	}

	return TransactionCharacteristics{
		read_only:            read_only
		isolation_level:      isolation_level
		condition_area_limit: limit
	}
}

// check_held_cursors checks that a holdable cursor that's still open from the
// previous SQL-transaction has the isolation level that's being set.
//
// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 1.a.ii
fn (conn Connection) check_held_cursors(level IsolationLevel) ! {
	if level != conn.isolation_level {
		for _, cursor in conn.cursors {
			if cursor.hold && cursor.is_open {
				return sqlstate_25008()
			}
		}
	}
}

// condition_area_limit is the <number of conditions> of a <diagnostics size>.
fn condition_area_limit(mut conn Connection, params map[string]Value, size DiagnosticsSize) !int {
	mut c := Compiler{
		conn:   conn
		params: params
	}
	v := size.number_of_conditions.compile(mut c)!.run(mut conn, Row{}, params)!

	// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 6
	if !v.typ.uses_int() && !(v.typ.typ in [.is_numeric, .is_decimal] && v.typ.scale == 0) {
		return sqlstate_42804('for DIAGNOSTICS SIZE', 'exact numeric with scale 0', v.typ.str())
	}

	// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>, General Rules, 3
	// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 2
	n := v.as_int()
	if v.is_null || n < 1 {
		return sqlstate_35000()
	}

	// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 3
	if n > max_conditions {
		conn.add_warning(sqlstate_01012())
		return max_conditions
	}

	return int(n)
}

// initiate_transaction sets the access mode, isolation level and condition area
// limit of an SQL-transaction that is being initiated. The limit is
// max_conditions if it's 0. The characteristics of a SET TRANSACTION are only for
// the next SQL-transaction. A new SQL-session, and the SQL-transaction after a
// COMMIT or ROLLBACK, have the enduring transaction characteristics (see
// enduring_characteristics).
//
// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 7
// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 10.b.i
// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.h.ii.1
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 9.c, 13.b and 13.e
// enduring_characteristics are the characteristics of an SQL-transaction that
// doesn't have its own. The isolation level is SERIALIZABLE, unless the
// connection was opened with another ConnectionOptions.isolation_level, the
// access mode is READ WRITE (unless the isolation level is READ UNCOMMITTED) and
// the condition area limit is max_conditions.
//
// ISO/IEC 9075-2:2016(E), 4.41.4, Isolation levels of SQL-transactions
fn (conn Connection) enduring_characteristics() TransactionCharacteristics {
	return TransactionCharacteristics{
		read_only:       conn.default_isolation_level == .read_uncommitted
		isolation_level: conn.default_isolation_level
	}
}

fn (mut conn Connection) initiate_transaction(characteristics TransactionCharacteristics) {
	conn.read_only = characteristics.read_only
	conn.isolation_level = characteristics.isolation_level
	conn.condition_area_limit = if characteristics.condition_area_limit > 0 {
		characteristics.condition_area_limit
	} else {
		max_conditions
	}
	conn.next_transaction = none
}

// changes_database is true for a statement that always changes the database. On
// its own, a SERIALIZABLE transaction must wait for other SERIALIZABLE
// transactions, see isolation.v. It can't be used in a READ ONLY transaction.
fn (p PreparedStmt) changes_database() bool {
	return p.changes_database_name() != ''
}

// changes_database_name is the name of a statement that always changes the
// database, otherwise it's empty. NEXT VALUE FOR doesn't count, because changes
// to a sequence generator aren't part of the SQL-transaction.
fn (p PreparedStmt) changes_database_name() string {
	return match p.stmt {
		AlterSequenceGeneratorStatement { 'ALTER SEQUENCE' }
		AlterTableStatement { 'ALTER TABLE' }
		DeleteStatementPositioned, DeleteStatementSearched { 'DELETE' }
		DropSchemaStatement { 'DROP SCHEMA' }
		DropSequenceGeneratorStatement { 'DROP SEQUENCE' }
		DropTableStatement { 'DROP TABLE' }
		InsertStatement { 'INSERT' }
		SchemaDefinition { 'CREATE SCHEMA' }
		SequenceGeneratorDefinition { 'CREATE SEQUENCE' }
		TableDefinition { 'CREATE TABLE' }
		UpdateStatementPositioned, UpdateStatementSearched { 'UPDATE' }
		else { '' }
	}
}
