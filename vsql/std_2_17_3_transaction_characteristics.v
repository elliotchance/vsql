module vsql

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>
//
// Specify transaction characteristics.

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
	// isolation_level is SERIALIZABLE by default (4.41.4).
	isolation_level IsolationLevel = .serializable
}

// new_transaction_characteristics returns the characteristics from a list of
// <transaction mode>s, after checking the Syntax Rules.
fn new_transaction_characteristics(modes []IsolationLevel) !TransactionCharacteristics {
	if modes.len > 1 {
		return sqlstate_42601('isolation level is specified more than once')
	}

	return TransactionCharacteristics{
		isolation_level: modes[0]
	}
}

// begin_transaction must be called before a statement runs. If the statement
// starts an implicit SQL-transaction, the transaction gets the characteristics
// from SET TRANSACTION (if any).
fn (mut conn Connection) begin_transaction(stmt Stmt) ! {
	changes_database := match stmt {
		CommitStatement, RollbackStatement, SetCatalogStatement, SetSchemaStatement,
		SetTransactionStatement, StartTransactionStatement {
			// These do not start an SQL-transaction.
			return
		}
		QueryExpression, SetConstraintsModeStatement {
			false
		}
		AlterSequenceGeneratorStatement, AlterTableStatement, DeleteStatementSearched,
		DropSchemaStatement, DropSequenceGeneratorStatement, DropTableStatement,
		InsertStatement, SchemaDefinition, SequenceGeneratorDefinition, TableDefinition,
		UpdateStatementSearched {
			true
		}
	}

	if !conn.in_transaction() {
		characteristics := conn.next_transaction or { TransactionCharacteristics{} }
		conn.isolation_level = characteristics.isolation_level
		conn.next_transaction = none

		// A statement that changes the database outside of a transaction is a
		// transaction of its own. It must wait for other REPEATABLE READ and
		// SERIALIZABLE transactions too, see isolation.v.
		if changes_database && conn.isolation_level.locks_transaction() {
			conn.lock_transaction()!
		}
	}
}
