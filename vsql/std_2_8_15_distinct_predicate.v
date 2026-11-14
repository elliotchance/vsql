module vsql

// ISO/IEC 9075-2:2016(E), 8.15, <distinct predicate>
//
// Specify a test of whether two row values are distinct.

// DistinctPredicate for "IS DISTINCT FROM" and "IS NOT DISTINCT FROM". Either
// side can be a row.
struct DistinctPredicate {
	left  RowValueConstructorPredicand
	right RowValueConstructorPredicand
	not   bool
}

// DistinctPredicatePart2 is the "IS [ NOT ] DISTINCT FROM <row value
// predicand>" of a <distinct predicate>.
struct DistinctPredicatePart2 {
	right RowValueConstructorPredicand
	not   bool
}

fn (e DistinctPredicate) pstr(params map[string]Value) string {
	if e.not {
		return '${e.left.pstr(params)} IS NOT DISTINCT FROM ${e.right.pstr(params)}'
	}

	return '${e.left.pstr(params)} IS DISTINCT FROM ${e.right.pstr(params)}'
}

fn (e DistinctPredicate) compile(mut c Compiler) !CompileResult {
	// ISO/IEC 9075-2:2016(E), 8.15, <distinct predicate>, Syntax Rules, 1-3:
	// both sides have the same degree and their respective fields are
	// comparable. Each field is an operand of an equality operation (Syntax
	// Rules, 5), which is the same check as for a comparison.
	//
	// So a dynamic parameter has the type of the field in the same position of
	// the other side, as it does in a comparison.
	//
	// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 5.a.xxi
	typed := c.with_row_types([e.left.compile_fields(mut c)!, e.right.compile_fields(mut c)!])
	left, right := typed[0], typed[1]
	c.check_row_comparison(left.map(it.typ), right.map(it.typ), null_parameters(left, right))!

	return CompileResult{
		run:          fn [e, left, right] (mut conn Connection, data Row, params map[string]Value) !Value {
			x := run_fields(mut conn, left, data, params)!
			y := run_fields(mut conn, right, data, params)!

			// ISO/IEC 9075-2:2016(E), 8.15, <distinct predicate>, General Rules,
			// 1.c.iv: rows are distinct if any of their respective fields are.
			// A value that isn't a row is the same as a row with one field.
			// Every pair is compared, so that fields that can't be compared are
			// always an error.
			mut distinct := false
			for i, value in x {
				if values_are_distinct(conn, value, y[i])! {
					distinct = true
				}
			}

			// ISO/IEC 9075-2:2016(E), 8.15, <distinct predicate>, Syntax Rules,
			// 6: IS NOT DISTINCT FROM is NOT (X IS DISTINCT FROM Y). So the
			// result is never Unknown.
			return new_boolean_value(distinct != e.not)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: left.any(it.contains_agg) || right.any(it.contains_agg)
	}
}

// values_are_distinct is whether two values (that aren't rows) are distinct.
fn values_are_distinct(conn &Connection, x Value, y Value) !bool {
	// ISO/IEC 9075-2:2016(E), 8.15, <distinct predicate>, General Rules, 1.a
	// and 1.b: two NULLs aren't distinct, and a NULL is distinct from any value
	// that isn't NULL.
	if x.is_null || y.is_null {
		return x.is_null != y.is_null
	}

	// ISO/IEC 9075-2:2016(E), 8.15, <distinct predicate>, General Rules, 1.c.i:
	// otherwise they're distinct when they aren't equal (see compare).
	// User-defined, reference, array and multiset types (1.c.ii, 1.c.iii, 1.c.v
	// and 1.c.vi) are not supported.
	return compare(conn, x, y)! != .is_equal
}
