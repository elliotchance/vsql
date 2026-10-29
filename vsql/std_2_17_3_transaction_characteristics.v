module vsql

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>
//
// Specify transaction characteristics.
//
// Only <diagnostics size> is supported, which is the most conditions that are
// kept in Connection.warnings during the SQL-transaction.

// max_conditions is the most conditions that can be kept in Connection.warnings,
// and the number when there isn't a <diagnostics size> (SR 7).
const max_conditions = 100

// A TransactionMode is a <diagnostics size>.
struct TransactionMode {
	number_of_conditions ValueSpecification
}

// condition_area_limit is the <number of conditions> of modes, or 0 if there
// isn't one.
fn condition_area_limit(mut conn Connection, params map[string]Value, modes []TransactionMode) !int {
	// - SR 2.
	if modes.len > 1 {
		return sqlstate_42601('DIAGNOSTICS SIZE can only be used once')
	}
	if modes.len == 0 {
		return 0
	}

	mut c := Compiler{
		conn:   conn
		params: params
	}
	v := modes[0].number_of_conditions.compile(mut c)!.run(mut conn, Row{}, params)!

	// - SR 6.
	if !v.typ.uses_int() && !(v.typ.typ in [.is_numeric, .is_decimal] && v.typ.scale == 0) {
		return sqlstate_42804('for DIAGNOSTICS SIZE', 'exact numeric with scale 0', v.typ.str())
	}

	// - 17.1 GR 3, 17.2 GR 2.
	n := v.as_int()
	if v.is_null || n < 1 {
		return sqlstate_35000()
	}

	// - 17.2 GR 3.
	if n > max_conditions {
		conn.add_warning(sqlstate_01012())
		return max_conditions
	}

	return int(n)
}

// initiate_transaction sets the condition area limit of an SQL-transaction
// that is being initiated (ISO/IEC 9075-2:2016(E), 17.2, General Rule 7), which
// is the <number of conditions> limit, or max_conditions if it's 0. The
// characteristics of a SET TRANSACTION are only for the next SQL-transaction.
fn (mut conn Connection) initiate_transaction(limit int) {
	conn.condition_area_limit = if limit > 0 { limit } else { max_conditions }
	conn.next_condition_area_limit = 0
}
