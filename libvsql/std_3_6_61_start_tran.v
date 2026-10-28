module main

// ISO/IEC 9075-3:2003(E), 6.61, StartTran
//
// Explicitly start an SQL-transaction and set its characteristics.
//
// vsql transactions are always READ WRITE and READ COMMITTED, so a READ ONLY
// transaction, or an isolation level that's stricter than READ COMMITTED,
// can't be started.

// Codes from Table 36, "Values for TRANSACTION ACCESS MODE with StartTran".
const sql_transaction_read_only = 0x00000001
const sql_transaction_read_write = 0x00000002

// Codes from Table 35, "Values for TRANSACTION ISOLATION OPTION with GetInfo
// and StartTran".
const sql_transaction_read_uncommitted = 0x00000001
const sql_transaction_read_committed = 0x00000002
const sql_transaction_repeatable_read = 0x00000004
const sql_transaction_serializable = 0x00000008

@[export: 'SQLStartTran']
fn sql_start_tran(handle_type i16, handle SQLInteger, access_mode SQLInteger, isolation_level SQLInteger) i16 {
	h := i64(handle)
	mut diag, l1 := transaction_handles(handle_type, h) or { return sql_invalid_handle }
	diag.clear()

	return start_tran(handle_type, h, l1, i64(access_mode), i64(isolation_level)) or {
		diag.error(err)
	}
}

fn start_tran(handle_type i16, h i64, l1 []i64, access_mode i64, isolation_level i64) !i16 {
	if handle_type in [sql_handle_stmt, sql_handle_desc] {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	// - 3.c.ii.3. If there is no established SQL-connection associated with C,
	// then an exception condition is raised: connection exception —
	// connection does not exist.
	if handle_type == sql_handle_dbc && l1.len == 0 {
		return cli_error('08003', 'connection does not exist')
	}

	// - 4. If an SQL-transaction is currently active on any of the
	// SQL-connections contained in L1, then an exception condition is raised:
	// invalid transaction state — active SQL-transaction.
	for dh in l1 {
		if transaction_active(sql_handle_dbc, dh) {
			return cli_error('25001', 'active SQL-transaction')
		}
	}

	// - 5, 6. AM and IL must be one of the codes in Table 36 and Table 35,
	// otherwise an exception condition is raised: CLI-specific condition —
	// invalid attribute identifier.
	if access_mode !in [i64(sql_transaction_read_only), sql_transaction_read_write]
		|| isolation_level !in [i64(sql_transaction_read_uncommitted), sql_transaction_read_committed,
			sql_transaction_repeatable_read, sql_transaction_serializable] {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	// - 8, 9. The access mode and isolation level of TXN are set.
	if access_mode == sql_transaction_read_only {
		return cli_error('HYC00', 'optional feature not implemented: READ ONLY transactions')
	}
	if isolation_level in [i64(sql_transaction_repeatable_read), sql_transaction_serializable] {
		return cli_error('HYC00', 'optional feature not implemented: isolation level stricter than READ COMMITTED')
	}

	// - 10. TXN is started in each SQL-connection contained in L1.
	for dh in l1 {
		mut dbc := dbcs[dh] or { continue }
		mut conn := dbc.conn or { continue }
		conn.query('START TRANSACTION')!
	}

	return sql_success
}
