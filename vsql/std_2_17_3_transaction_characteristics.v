module vsql

// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>
//
// Specify transaction characteristics.
//
// Only <diagnostics size> is supported, which is the most conditions that are
// kept in Connection.warnings during the SQL-transaction.

// max_conditions is the most conditions that can be kept in Connection.warnings,
// and the number when there isn't a <diagnostics size>.
//
// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 7
const max_conditions = 100

// A TransactionMode is a <diagnostics size>.
struct TransactionMode {
	number_of_conditions ValueSpecification
}

// condition_area_limit is the <number of conditions> of modes, or 0 if there
// isn't one.
fn condition_area_limit(mut conn Connection, params map[string]Value, modes []TransactionMode) !int {
	// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 2
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

// initiate_transaction sets the condition area limit of an SQL-transaction
// that is being initiated, which is the <number of conditions> limit, or
// max_conditions if it's 0. The characteristics of a SET TRANSACTION are only
// for the next SQL-transaction. A new SQL-session, and the SQL-transaction
// after a COMMIT or ROLLBACK, have the limit of the enduring transaction
// characteristics, which is max_conditions.
//
// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 7
// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 10.b.i
// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.h.ii.1
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 9.c, 13.b and 13.e
fn (mut conn Connection) initiate_transaction(limit int) {
	conn.condition_area_limit = if limit > 0 { limit } else { max_conditions }
	conn.next_condition_area_limit = 0
}
