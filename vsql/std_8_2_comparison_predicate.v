module vsql

import strings

// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>
//
// Specify a comparison of two row values.
struct ComparisonPredicate {
	left  RowValueConstructorPredicand
	op    string
	right RowValueConstructorPredicand
}

fn (e ComparisonPredicate) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} ${e.op} ${e.right.pstr(params)}'
}

fn (e ComparisonPredicate) compile(mut c Compiler) !CompileResult {
	compiled_left := e.left.compile(mut c)!
	compiled_right := e.right.compile(mut c)!

	return CompileResult{
		run:          fn [e, compiled_left, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut left := compiled_left.run(mut conn, data, params)!
			mut right := compiled_right.run(mut conn, data, params)!

			cmp := compare(left, right)!
			if cmp == .is_unknown {
				return new_unknown_value()
			}

			return new_boolean_value(match e.op {
				'=' {
					cmp == .is_equal
				}
				'<>' {
					cmp != .is_equal
				}
				'>' {
					cmp == .is_greater
				}
				'<' {
					cmp == .is_less
				}
				'>=' {
					cmp == .is_greater || cmp == .is_equal
				}
				'<=' {
					cmp == .is_less || cmp == .is_equal
				}
				else {
					// This should not be possible, but it's to satisfy the required else.
					panic('invalid binary operator: ${e.op}')
				}
			})
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_left.contains_agg || compiled_right.contains_agg
	}
}

struct ComparisonPredicatePart2 {
	op   string
	expr RowValueConstructorPredicand
}

enum CompareResult as i8 {
	is_unknown = 0 // same as NULL
	is_less    = 1
	is_equal   = 2
	is_greater = 3
}

// compare() should only be used for comparison predicates (equality) but
// shouldn't be used for ordering.
fn compare(xv Value, yv Value) !CompareResult {
	// General Rules
	//
	// 1) Let XV and YV be two values represented by <value expression>s X and Y,
	// respectively. The result of:
	//
	// X <comp op> Y
	//
	// is determined as follows. Case:
	//
	//   a) If at least one of XV and YV is the null value, then
	//
	//   X <comp op> Y
	//
	//   is Unknown.
	if xv.is_null || yv.is_null {
		return .is_unknown
	}

	//   b) Otherwise,
	//
	//   Case:
	//
	//     i) If the declared types of XV and YV are row types with degree N, then
	//        let Xi, 1 (one) ≤ i ≤ N, denote a <value expression> whose value and
	//        declared type is that of the i-th field of XV and let Yi denote a
	//        <value expression> whose value and declared type is that of the i-th
	//        field of YV. The result of
	//
	//        X <comp op> Y
	//
	//        is determined as follows:
	//
	//        1) X = Y is True if and only if Xi = Yi is True for all i.
	//        2) X < Y is True if and only if Xi = Yi is True for all i < n and
	//           Xn < Yn for some n.
	//        3) X = Y is False if and only if NOT (Xi = Yi) is True for some i.
	//        4) X < Y is False if and only if X = Y is True or Y < X is True.
	//        5) X <comp op> Y is Unknown if X <comp op> Y is neither True nor
	//           False.
	//
	//     ii) If the declared types of XV and YV are array types or distinct
	//         types whose source types are array types and the cardinalities of
	//         XV and YV are N1 and N2, respectively, then let Xi,
	//         1 (one) ≤ i ≤ N1, denote a <value expression> whose value and
	//         declared type is that of the i-th element of XV and let Yi,
	//         1 (one) ≤ i ≤ N2, denote a <value expression> whose value and
	//         declared type is that of the i-th element of YV. The result of
	//
	//         X <comp op> Y
	//
	//         is determined as follows:
	//
	//         1) X = Y is True if N1 = 0 (zero) and N2 = 0 (zero).
	//         2) X = Y is True if N1 = N2 and, for all i, Xi = Yi is True.
	//         3) X = Y is False if and only if one of the following is true:
	//            A) N1 ≠ N2.
	//            B) N1 = N2 and for some i, 1 (one) ≤ i ≤ N1, NOT (Xi = Yi) is
	//               True.
	//         4) X <comp op> Y is Unknown if X <comp op> Y is neither True nor
	//            False.
	//
	//     iii) If the declared types of XV and YV are multiset types or distinct
	//          types whose source types are multiset types and the cardinalities
	//          of XV and YV are N1 and N2, respectively, then the result of
	//
	//          X <comp op> Y
	//
	//          is determined as follows. Case:
	//          1) X = Y is True if N1 = 0 (zero) and N2 = 0 (zero).
	//          2) X = Y is True if N1 = N2, and there exist an enumeration XVEj,
	//             1 (one) ≤ j ≤ N1, of the elements of XV and an enumeration
	//             YVEj, 1 (one) ≤ j ≤ N1, of the elements of YV such that for all
	//             j, XVEj = YVEj.
	//          3) X = Y is Unknown if N1 = N2, and there exist an enumeration
	//             XVEj, 1 (one) ≤ j ≤ N1, of the elements of XV and an
	//             enumeration YVEj, 1 (one) ≤ j ≤ N1, of the elements of YV such
	//             that for all j, “XVEj = YVEj” is either True or Unknown.
	//          4) Otherwise, X = Y is False.
	//
	//     iv) If the declared types of XV and YV are user-defined types, then let
	//         UDTx and UDTy be respectively the declared types of XV and YV. The
	//         result of
	//
	//         X <comp op> Y
	//
	//         is determined as follows:
	//
	//         1) If the comparison category of UDTx is MAP, then let HF1 be the
	//            <routine name> with explicit <schema name> of the comparison
	//            function of UDTx and let HF2 be the <routine name> with explicit
	//            <schema name> of the comparison function of UDTy. If HF1
	//            identifies an SQL-invoked method, then let HFX be X.HF1;
	//            otherwise, let HFX be HF1(X). If HF2 identifies an SQL-invoked
	//            method, then let HFY be Y.HF2; otherwise, let HFY be HF2(Y).
	//
	//            X <comp op> Y
	//
	//            has the same result as
	//
	//            HFX <comp op> HFY
	//
	//         2) If the comparison category of UDTx is RELATIVE, then:
	//
	//            A) Let RF be the <routine name> with explicit <schema name> of
	//               the comparison function of UDTx.
	//
	//            B) X = Y
	//               has the same result as
	//               RF (X, Y ) = 0
	//
	//            C) X < Y
	//               has the same result as
	//               RF (X, Y ) = -1
	//
	//            D) X <> Y
	//               has the same result as
	//               RF (X, Y ) <> 0
	//
	//            E) It is implementation-dependent whether X > Y
	//               has the same result as
	//               RF (X, Y ) = 1
	//               or has the same result as
	//               RF (Y, X ) = -1 F) X<=Y
	//               has the same result as
	//               RF (X, Y ) = -1 OR RF (X, Y ) = 0
	//
	//            G) It is implementation-dependent whether X >= Y
	//               has the same result as
	//               RF (X, Y ) = 1 OR RF (X, Y ) = 0 or has the same result as
	//               RF (Y, X ) = -1 OR RF (X, Y ) = 0
	//
	//               NOTE 337 — Since it is implementation-defined whether to use
	//               the syntactic transformation to define all comparisons in
	//               terms of = and <, for portability, the application should
	//               ensure that RF (X, Y) = -RF (Y, X) for all X and Y.
	//
	//          3) If the comparison category of UDTx is STATE, then:
	//
	//             A) Let SF be the <routine name> of the comparison function of
	//                UDTx.
	//
	//             B) X = Y
	//                has the same result as
	//                SF (X, Y ) = TRUE
	//
	//        v) Otherwise, the result of
	//           X <comp op> Y
	//           is True or False as follows:
	//
	//           1) X=Y
	//              is True if and only if XV and YV are equal.
	//           2) X<Y
	//              is True if and only if XV is less than YV.
	//           3) X <comp op> Y
	//              is False if and only if
	//              X <comp op> Y
	//              is not True
	//
	// Not applicable.

	// 2) Numbers are compared with respect to their algebraic value.
	if xv.typ.typ.is_number() && yv.typ.typ.is_number() {
		return compare_numbers(xv, yv)
	}

	// 3) The comparison of two character strings ...
	if xv.typ.typ.is_string() && yv.typ.typ.is_string() {
		return compare_strings(xv, yv)
	}

	// 4) The comparison of two binary string values, X and Y, of which at least
	//    one is a binary large object string value, is determined by comparison
	//    of their octets with the same ordinal position. Let Xi and Yi be the
	//    comparison of two binary string values, X and Y, of which at least one
	//    is a binary large object string values of the i-th octets of X and Y,
	//    respectively, and let Lx be the length in octets of X and let Ly be the
	//    length in octets of Y. X is equal to Y if and only if Lx = Ly and if
	//    Xi = Yi for all i.
	//
	// Not applicable.

	// 5) The comparison of two binary string values X and Y, neither of which is
	//    a binary large object string value, is determined as follows:
	//
	//    a) Let Lx be the length in octets of X and let Ly be the length in
	//       octets of Y. Let Xi, 1 (one) ≤ i ≤ Lx, be the value of the i-th octet
	//       of X, and let Yi, 1 (one) ≤ i ≤ Ly, be the value of the i-th octet of
	//       Y.
	//
	//    b) If Lx = Ly and Xi = Yi, 1 (one) ≤ i ≤ Lx, then X is equal to Y.
	//
	//    c) If Lx < Ly, Xi = Yi for all i ≤ Lx, and the right-most Ly – Lx octets
	//       of Y are all X'00's, then it is imple- mentation-defined whether X is
	//       equal to Y or whether X is less than Y.
	//
	//    d) If Lx < Ly, Xi = Yi for all i ≤ Lx, and at least one of the
	//       right-most Ly – Lx octets of Y is not X'00', then X is less than Y.
	//
	//    e) If Xj < Yj, for some j, 0 (zero) < j ≤ minimum(Lx, Ly), and Xi = Yi
	//       for all i < j, then X is less than Y.
	//
	// Not applicable.

	// 6) The comparison of two datetimes ...
	if xv.typ.typ.is_datetime() && yv.typ.typ.is_datetime() {
		return compare_datetimes(xv, yv)
	}

	// 7) The comparison of two intervals is determined by the comparison of their
	//    corresponding values after conversion to integers in some common base
	//    unit. Let X and Y be the two intervals to be compared. Let A TO B be the
	//    specified or implied interval qualifier of X and C TO D be the specified
	//    or implied interval qualifier of Y. Let T be the least significant
	//    <primary datetime field> of B and D and let U be an interval qualifier
	//    of the form T(N), where N is an <interval leading field precision> large
	//    enough so that significance is not lost in the CAST operation.
	//
	//    Let XVE be the <value expression> CAST ( X AS INTERVAL U )
	//    Let YVE be the <value expression> CAST ( Y AS INTERVAL U )
	//
	//    a) X is equal to Y if and only if
	//       CAST ( XVE AS INTEGER ) = CAST ( YVE AS INTEGER )
	//       is True.
	//
	//    b) X is less than Y if and only if
	//       CAST ( XVE AS INTEGER ) < CAST ( YVE AS INTEGER )
	//       is True.
	//
	// Not applicable.

	// 8) In comparisons of boolean values ...
	if xv.typ.typ == .is_boolean && yv.typ.typ == .is_boolean {
		return compare_booleans(xv, yv)
	}

	// 9) The result of comparing two REF values X and Y is determined by the
	//    comparison of their octets with the same ordinal position. Let Lx be the
	//    length in octets of X and let Ly be the length in octets of Y. Let Xi
	//    and Yi, 1 (one) ≤ i ≤ Lx, be the values of the i-th octets of X and Y,
	//    respectively. X is equal to Y if and only if
	//    Lx = Ly and, for all i, Xi = Yi.
	//
	// Not applicable.

	return sqlstate_42883('cannot compare ${xv.typ} and ${yv.typ}')
}

fn compare_datetimes(xv Value, yv Value) CompareResult {
	// 6) The comparison of two datetimes is determined according to the interval
	//    resulting from their subtraction. Let X and Y be the two values to be
	//    compared and let H be the least significant <primary datetime field> of
	//    X and Y, including fractional seconds precision if the data type is time
	//    or timestamp.
	//
	// compare_strings is only invoked when both sides are known to use
	// time_value.
	//
	// TODO(elliotchance): <primary datetime field> needs to be taken into account
	//  when it is supported.
	x := unsafe { xv.v.time_value }.i64()
	y := unsafe { yv.v.time_value }.i64()

	//    a) X is equal to Y if and only if
	//       ( X - Y ) INTERVAL H = INTERVAL '0' H
	//       is True.
	diff := x - y
	if diff == 0 {
		return .is_equal
	}

	//    b) X is less than Y if and only if
	//       ( X - Y ) INTERVAL H < INTERVAL '0' H is True.
	//
	//       NOTE 338 — Two datetimes are comparable only if they have the same
	//       <primary datetime field>s; see Subclause 4.6.2, “Datetimes”.
	if diff < 0 {
		return .is_less
	}

	return .is_greater
}

fn compare_numbers(xv Value, yv Value) !CompareResult {
	// 2) Numbers are compared with respect to their algebraic value.
	if (xv.typ.typ == .is_decimal || xv.typ.typ == .is_numeric)
		&& (yv.typ.typ == .is_decimal || yv.typ.typ == .is_numeric) {
		return xv.numeric_value().compare(yv.numeric_value())
	}

	if (xv.typ.typ == .is_smallint || xv.typ.typ == .is_integer || xv.typ.typ == .is_bigint)
		&& (yv.typ.typ == .is_smallint || yv.typ.typ == .is_integer || yv.typ.typ == .is_bigint) {
		x := xv.int_value()
		y := yv.int_value()

		if x < y {
			return .is_less
		}

		if x > y {
			return .is_greater
		}

		return .is_equal
	}

	x := xv.as_f64()!
	y := yv.as_f64()!

	if x < y {
		return .is_less
	}

	if x > y {
		return .is_greater
	}

	return .is_equal
}

fn compare_strings(xv Value, yv Value) CompareResult {
	// 3) The comparison of two character strings is determined as follows:

	// compare_strings is only invoked when both sides are known to use
	// string_value.
	mut x := unsafe { xv.v.string_value }
	mut y := unsafe { yv.v.string_value }

	//    a) The Syntax Rules of Subclause 9.15, “Collation determination”, are
	//       applied with the set of declared types of the two character strings
	//       as TYPESET; let CS be the COLL returned from the application of those
	//       Syntax Rules.
	//
	// Not applicable.

	//    b) If the length in characters of X is not equal to the length in
	//       characters of Y, then the shorter string is effectively replaced, for
	//       the purposes of comparison, with a copy of itself that has been
	//       extended to the length of the longer string by concatenation on the
	//       right of one or more pad characters, where the pad character is
	//       chosen based on CS. If CS has the NO PAD characteristic, then the pad
	//       character is an implementation-dependent character different from any
	//       character in the character set of X and Y that collates less than any
	//       string under CS. Otherwise, the pad character is a <space>.
	len_x := x.len
	len_y := y.len

	if len_x < len_y {
		x += strings.repeat(` `, len_y - len_x)
	} else if len_y < len_x {
		y += strings.repeat(` `, len_x - len_y)
	}

	//    c) The result of the comparison of X and Y is given by the collation CS.
	if x < y {
		return .is_less
	}

	if x > y {
		return .is_greater
	}

	return .is_equal

	//    d) Depending on the collation, two strings may compare as equal even if
	//       they are of different lengths or contain different sequences of
	//       characters. When any of the operations MAX, MIN, and DISTINCT
	//       reference a grouping column, and the UNION, EXCEPT, and INTERSECT
	//       operators refer to character strings, the specific value selected by
	//       these operations from a set of such equal values is
	//       implementation-dependent.
	//
	// Not applicable.
}

fn compare_booleans(xv Value, yv Value) CompareResult {
	// 8) In comparisons of boolean values, True is greater than False
	//
	// compare_booleans is only invoked when both sides are known to use
	// bool_value.
	x := unsafe { xv.v.bool_value }
	y := unsafe { yv.v.bool_value }

	if x == .is_true && y == .is_false {
		return .is_greater
	}

	if x == .is_false && y == .is_true {
		return .is_less
	}

	return .is_equal
}
