module vsql

// ISO/IEC 9075-2:2023, 8.14, <overlaps predicate>
//
// Specify a test for an overlap between two datetime periods.

// OverlapsPredicate is "(D1, E1) OVERLAPS (D2, E2)". Each period is a start and
// an end, in either order. The end can't be an INTERVAL, since intervals aren't
// supported (F052).
struct OverlapsPredicate {
	left  RowValueConstructorPredicand
	right RowValueConstructorPredicand
}

fn (e OverlapsPredicate) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} OVERLAPS ${e.right.pstr(params)}'
}

fn (e OverlapsPredicate) compile(mut c Compiler) !CompileResult {
	compiled_left := e.left.compile_fields(mut c)!
	compiled_right := e.right.compile_fields(mut c)!

	// ISO/IEC 9075-2:2023, 8.14, <overlaps predicate>, Syntax Rules, 1
	for compiled in [compiled_left, compiled_right] {
		if compiled.len != 2 {
			return sqlstate_42601('OVERLAPS needs a row of degree 2, not ${compiled.len}')
		}
	}

	// ISO/IEC 9075-2:2023, 8.14, <overlaps predicate>, Syntax Rules, 2 and
	// 3: every field is a datetime, and they must all be comparable. A dynamic
	// parameter whose value is NULL is allowed, as it is for a comparison (see
	// check_comparison).
	for field in [compiled_left[0], compiled_left[1], compiled_right[0], compiled_right[1]] {
		if !field.null_parameter && !field.typ.typ.is_datetime() {
			return sqlstate_42804('in OVERLAPS', 'DATE, TIME or TIMESTAMP', field.typ.str())
		}
	}
	for pair in [[compiled_left[0], compiled_right[0]], compiled_left, compiled_right] {
		c.check_comparison(pair[0].typ, pair[1].typ, pair[0].null_parameter
			|| pair[1].null_parameter)!
	}

	return CompileResult{
		run:          fn [compiled_left, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			left := run_fields(mut conn, compiled_left, data, params)!
			right := run_fields(mut conn, compiled_right, data, params)!

			// ISO/IEC 9075-2:2023, 8.14, <overlaps predicate>, General
			// Rules, 1: a row that's the null value (every field is NULL) makes
			// the result Unknown.
			if (left[0].is_null && left[1].is_null) || (right[0].is_null && right[1].is_null) {
				return new_unknown_value()
			}

			// ISO/IEC 9075-2:2023, 8.14, <overlaps predicate>, General
			// Rules, 2 to 6: each period is put in order, with a NULL start
			// becoming the end.
			s1, t1 := overlaps_period(conn, left[0], left[1])!
			s2, t2 := overlaps_period(conn, right[0], right[1])!

			// ISO/IEC 9075-2:2023, 8.14, <overlaps predicate>, General
			// Rules, 7:
			//
			//   ( S1 > S2 AND NOT ( S1 >= T2 AND T1 >= T2 ) )
			//   OR ( S2 > S1 AND NOT ( S2 >= T1 AND T2 >= T1 ) )
			//   OR ( S1 = S2 AND ( T1 <> T2 OR T1 = T2 ) )
			//
			// Periods that only share an endpoint don't overlap, unless one of
			// them is a single point at the start of the other.
			a := truth_and(overlaps_truth(conn, .greater_than, s1, s2)!, truth_not(truth_and(overlaps_truth(conn,
				.greater_than_or_equal, s1, t2)!, overlaps_truth(conn, .greater_than_or_equal,
				t1, t2)!)))
			b := truth_and(overlaps_truth(conn, .greater_than, s2, s1)!, truth_not(truth_and(overlaps_truth(conn,
				.greater_than_or_equal, s2, t1)!, overlaps_truth(conn, .greater_than_or_equal,
				t2, t1)!)))
			d := truth_and(overlaps_truth(conn, .equal, s1, s2)!, truth_or(overlaps_truth(conn,
				.not_equal, t1, t2)!, overlaps_truth(conn, .equal, t1, t2)!))

			return truth_or(truth_or(a, b), d).value()
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_left.any(it.contains_agg) || compiled_right.any(it.contains_agg)
	}
}

// overlaps_period returns the start and end of a period given as (D, E). If D
// is NULL or E < D, they are swapped.
//
// ISO/IEC 9075-2:2023, 8.14, <overlaps predicate>, General Rules, 4 and 6
fn overlaps_period(conn &Connection, d Value, e Value) !(Value, Value) {
	if d.is_null || overlaps_truth(conn, .less_than, e, d)! == .is_true {
		return e, d
	}

	return d, e
}

// overlaps_truth is the result of "X <op> Y".
fn overlaps_truth(conn &Connection, op ComparisonOperator, x Value, y Value) !Truth {
	return op.truth(compare(conn, x, y)!)
}
