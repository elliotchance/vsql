module vsql

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>
//
// Specify transaction characteristics.

struct TransactionCharacteristics {
	// read_only is the <transaction access mode>. READ WRITE is the default.
	read_only bool
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
		conn.next_transaction = none
	}

	if conn.read_only && name != '' {
		return sqlstate_25006('cannot execute ${name}')
	}
}
