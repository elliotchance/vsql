module vsql

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>
//
// Specify transaction characteristics.

type TransactionMode = IsolationLevel | TransactionAccessMode

enum TransactionAccessMode {
	read_only
	read_write
}

// IsolationLevel is the <level of isolation>. An SQL-implementation may use a
// stricter level than the one that is asked for (17.2, General Rule 6), so READ
// UNCOMMITTED runs as READ COMMITTED, and REPEATABLE READ runs as SERIALIZABLE.
// See isolation.v.
enum IsolationLevel {
	read_uncommitted
	read_committed
	repeatable_read
	serializable
}

// locks_transaction is true if the SQL-transaction must hold the isolation lock
// until it ends, so that no other transaction can commit in the meantime.
fn (level IsolationLevel) locks_transaction() bool {
	return level in [.repeatable_read, .serializable]
}

struct TransactionCharacteristics {
	// read_only is the <transaction access mode>. READ WRITE is the default.
	read_only bool
	// isolation_level is SERIALIZABLE by default (4.41.4).
	isolation_level IsolationLevel = .serializable
}

// new_transaction_characteristics returns the characteristics from a list of
// <transaction mode>s, after checking the Syntax Rules.
fn new_transaction_characteristics(modes []TransactionMode) !TransactionCharacteristics {
	mut access_mode := ?TransactionAccessMode(none)
	mut isolation_level := ?IsolationLevel(none)
	for mode in modes {
		match mode {
			TransactionAccessMode {
				if access_mode != none {
					return sqlstate_42601('transaction access mode is specified more than once')
				}
				access_mode = mode
			}
			IsolationLevel {
				if isolation_level != none {
					return sqlstate_42601('isolation level is specified more than once')
				}
				isolation_level = mode
			}
		}
	}

	level := isolation_level or { IsolationLevel.serializable }

	// READ UNCOMMITTED is READ ONLY, unless it's given as READ WRITE, which is
	// not allowed (Syntax Rules 4 and 5).
	if level == .read_uncommitted {
		if mode := access_mode {
			if mode == .read_write {
				return sqlstate_42601('READ WRITE cannot be used with READ UNCOMMITTED')
			}
		}

		return TransactionCharacteristics{
			read_only:       true
			isolation_level: level
		}
	}

	return TransactionCharacteristics{
		read_only:       if mode := access_mode { mode == .read_only } else { false }
		isolation_level: level
	}
}

// begin_access_mode must be called before a statement runs. If the statement
// starts an implicit SQL-transaction, the transaction gets the characteristics
// from SET TRANSACTION (if any). Then the statement fails if it would change
// the database in a read-only SQL-transaction. NEXT VALUE FOR is allowed,
// because sequence generators are not changed transactionally.
fn (mut conn Connection) begin_access_mode(stmt Stmt) ! {
	name := match stmt {
		CommitStatement, RollbackStatement, SetCatalogStatement, SetSchemaStatement,
		SetTransactionStatement, StartTransactionStatement {
			// These do not start an SQL-transaction.
			return
		}
		QueryExpression {
			''
		}
		AlterSequenceGeneratorStatement {
			'ALTER SEQUENCE'
		}
		DeleteStatementSearched {
			'DELETE'
		}
		DropSchemaStatement {
			'DROP SCHEMA'
		}
		DropSequenceGeneratorStatement {
			'DROP SEQUENCE'
		}
		DropTableStatement {
			'DROP TABLE'
		}
		InsertStatement {
			'INSERT'
		}
		SchemaDefinition {
			'CREATE SCHEMA'
		}
		SequenceGeneratorDefinition {
			'CREATE SEQUENCE'
		}
		TableDefinition {
			'CREATE TABLE'
		}
		UpdateStatementSearched {
			'UPDATE'
		}
	}

	if !conn.in_transaction() {
		characteristics := conn.next_transaction or { TransactionCharacteristics{} }
		conn.read_only = characteristics.read_only
		conn.isolation_level = characteristics.isolation_level
		conn.next_transaction = none
	}

	if conn.read_only && name != '' {
		return sqlstate_25006('cannot execute ${name}')
	}

	// A statement that changes the database outside of a transaction is a
	// transaction of its own. It must wait for other REPEATABLE READ and
	// SERIALIZABLE transactions too, see isolation.v.
	if !conn.in_transaction() && name != '' && conn.isolation_level.locks_transaction() {
		conn.lock_transaction(false)!
	}
}
