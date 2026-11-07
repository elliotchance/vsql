module vsql

import math

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>
//
// Specify a value computed from a collection of rows.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.16 (Data analysis operations involving tables)

type AggregateFunction = AggregateFunctionCount | RoutineInvocation

fn (e AggregateFunction) pstr(params map[string]Value) string {
	return match e {
		AggregateFunctionCount { 'COUNT(*)' }
		RoutineInvocation { e.pstr(params) }
	}
}

fn (e AggregateFunction) compile(mut c Compiler) !CompileResult {
	match e {
		AggregateFunctionCount {
			c.aggregates << e

			compiled := Identifier{
				custom_id:  'COUNT(*)'
				custom_typ: new_type('INTEGER', 0, 0)
			}.compile(mut c)!

			return CompileResult{
				run:          fn [compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
					return compiled.run(mut conn, data, params)!
				}
				typ:          new_type('INTEGER', 0, 0)
				contains_agg: true
			}
		}
		RoutineInvocation {
			return e.compile(mut c)!
		}
	}
}

struct AggregateFunctionCount {}

// non_null_values removes NULLs before a general set function is applied. If
// all values are NULL (or there are no values) the result will be NULL.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.a
fn non_null_values(values []Value) []Value {
	return values.filter(!it.is_null)
}

// distinct_values removes NULLs and duplicates for a general set function with
// DISTINCT, such as COUNT(DISTINCT x). Values are duplicates if they're equal
// with =, so 1.5 and 1.50 (or 'a' and 'a ') are the same value.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.b
fn distinct_values(conn &Connection, values []Value) ![]Value {
	mut result := []Value{}
	for value in non_null_values(values) {
		mut is_duplicate := false
		for existing in result {
			if compare(conn, value, existing)! == .is_equal {
				is_duplicate = true
				break
			}
		}
		if !is_duplicate {
			result << value
		}
	}

	return result
}

// set_function_type is the declared type of the result of a general set
// function with an argument of type t.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 4 and 7
fn set_function_type(name string, t Type) Type {
	// The implementation-defined type of COUNT (SR 4), and of REGR_COUNT, which
	// also counts rows (SR 9.c.i).
	if name in ['COUNT', 'REGR_COUNT'] {
		return new_type('INTEGER', 0, 0)
	}

	// The implementation-defined approximate numeric type of the variance and
	// standard deviation (SR 7.h.ii, 7.i and 7.j), and of the other binary set
	// functions (SR 9.c.ii.2). A DOUBLE PRECISION is at least as precise as any
	// argument.
	if name in ['STDDEV_POP', 'STDDEV_SAMP', 'VAR_POP', 'VAR_SAMP']
		|| name in binary_set_functions {
		return new_type('DOUBLE PRECISION', 0, 0)
	}

	// The sum of exact numbers keeps the scale (SR 7.g.ii). It has no limit on the
	// precision because the sum may need more digits than any of the values. The
	// sum of integers is a BIGINT so that it's less likely to overflow.
	if name == 'SUM' {
		return match t.typ {
			.is_smallint, .is_integer, .is_bigint { new_type('BIGINT', 0, 0) }
			.is_numeric, .is_decimal { Type{t.typ, 0, t.scale, false} }
			else { Type{t.typ, 0, 0, false} }
		}
	}

	// MAX and MIN have the type of their argument (SR 7.f). So does AVG, which
	// is allowed because an exact numeric only needs at least the same precision
	// and scale (SR 7.g.iii), and an approximate numeric only needs at least the
	// same precision (SR 7.g.iv). The average is truncated to that scale.
	return Type{t.typ, t.size, t.scale, false}
}

// eval_set_function returns the result of the general set function (such as
// SUM) for the values of one group, where t is the declared type of the
// argument.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 3.e
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7
fn eval_set_function(mut conn Connection, name string, all_values []Value, t Type) !Value {
	values := non_null_values(all_values)
	typ := set_function_type(name, t)

	if name == 'COUNT' {
		return new_integer_value(values.len)
	}

	if values.len == 0 {
		return Value{
			typ:     typ
			is_null: true
		}
	}

	if name in ['STDDEV_POP', 'STDDEV_SAMP', 'VAR_POP', 'VAR_SAMP'] {
		return eval_variance(name, values)!
	}

	if name in ['MAX', 'MIN'] {
		// The comparison rules are the same as the comparison predicate (GR 7.d.iv).
		want := if name == 'MAX' { CompareResult.is_greater } else { CompareResult.is_less }
		mut result := values[0]
		for value in values[1..] {
			if compare(conn, value, result)! == want {
				result = value
			}
		}

		return result
	}

	// SUM or AVG. An approximate numeric is added as a DOUBLE PRECISION, and an
	// exact numeric is added exactly before it's cast to the result type, which
	// raises 22003 when the sum doesn't fit (GR 3.e and 7.d.v).
	if typ.typ in approximate_types {
		mut sum := 0.0
		for value in values {
			sum += value.f64_value()
		}
		if name == 'AVG' {
			sum /= values.len
		}

		return approximate_value(sum, typ.typ)
	}

	mut sum := values[0].as_numeric()!
	for value in values[1..] {
		sum = sum.add(value.as_numeric()!)
	}
	if name == 'AVG' {
		sum = sum.divide(new_numeric_from_string(values.len.str()))!
	}

	return cast(mut conn, name, new_numeric_value_from_numeric(sum), typ)!
}

// binary_set_functions are the names of every <binary set function type>.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Format
const binary_set_functions = ['COVAR_POP', 'COVAR_SAMP', 'CORR', 'REGR_SLOPE', 'REGR_INTERCEPT',
	'REGR_COUNT', 'REGR_R2', 'REGR_AVGX', 'REGR_AVGY', 'REGR_SXX', 'REGR_SYY', 'REGR_SXY']

// Moments are the means and the sums of squared deviations from the means of
// the pairs of values of a set function, which give the same results as the
// sums used by the standard (such as S2-S1*S1/N for the sum of squares of a
// variance), but they don't lose all of their precision when the values are
// large and close together.
//
// The values are divided by a power of two that's at least the largest
// magnitude of each column (sx and sy) first, so that the squares can't
// overflow or underflow, and the results are scaled back at the end. The sums
// are calculated with the corrected two-pass algorithm, which subtracts the
// error of the mean. A sum of squares is exactly zero when every value is the
// same, and otherwise it's positive.
struct Moments {
mut:
	n      int
	sx     f64
	sy     f64
	mean_x f64 // of x / sx
	mean_y f64 // of y / sy
	sxx    f64 // sum of (x / sx - mean_x)^2
	syy    f64 // sum of (y / sy - mean_y)^2
	sxy    f64 // sum of (x / sx - mean_x) * (y / sy - mean_y)
}

fn new_moments(xs []f64, ys []f64) Moments {
	mut m := Moments{
		n: xs.len
	}
	mut same_x := true
	mut same_y := true
	for i, x in xs {
		m.sx = math.max(m.sx, math.abs(x))
		m.sy = math.max(m.sy, math.abs(ys[i]))
		same_x = same_x && x == xs[0]
		same_y = same_y && ys[i] == ys[0]
	}
	m.sx = power_of_two_scale(m.sx)
	m.sy = power_of_two_scale(m.sy)
	if m.n == 0 {
		return m
	}

	for i, x in xs {
		m.mean_x += x / m.sx
		m.mean_y += ys[i] / m.sy
	}
	m.mean_x /= m.n
	m.mean_y /= m.n

	mut dx_sum := 0.0
	mut dy_sum := 0.0
	for i, x in xs {
		dx := x / m.sx - m.mean_x
		dy := ys[i] / m.sy - m.mean_y
		dx_sum += dx
		dy_sum += dy
		m.sxx += dx * dx
		m.syy += dy * dy
		m.sxy += dx * dy
	}
	m.sxx = if same_x { 0.0 } else { m.sxx - dx_sum * dx_sum / m.n }
	m.syy = if same_y { 0.0 } else { m.syy - dy_sum * dy_sum / m.n }
	m.sxy -= dx_sum * dy_sum / m.n
	m.mean_x += dx_sum / m.n
	m.mean_y += dy_sum / m.n

	return m
}

// power_of_two_scale is the power of two that is at least the largest
// magnitude x, so that dividing by it is exact, or 1 if x is zero.
fn power_of_two_scale(x f64) f64 {
	if x == 0 {
		return 1
	}
	_, exp := math.frexp(x)

	return math.ldexp(1, exp)
}

// scaled_value is a result that was calculated from the values divided by sx
// or sy (x), multiplied by the factors to undo that. If the result is out of
// the range of a DOUBLE PRECISION, it's the null value for CORR, REGR_R2,
// REGR_SLOPE and REGR_INTERCEPT (when or_null is true), otherwise it's an
// exception.
//
// ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>, General Rules, 6
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 8.c.x.3, 8.c.xi.3, 8.c.xii.2 and 8.c.xiii.2
fn scaled_value(x f64, factors []f64, or_null bool) !Value {
	mut result := x
	for factor in factors {
		result *= factor
	}

	if math.is_inf(result, 0) || (result == 0 && x != 0) {
		if or_null {
			return null_double_precision()
		}

		return sqlstate_22003()
	}

	return new_double_precision_value(result)
}

fn null_double_precision() Value {
	return Value{
		typ:     new_type('DOUBLE PRECISION', 0, 0)
		is_null: true
	}
}

// eval_variance is the result of STDDEV_POP, STDDEV_SAMP, VAR_POP or VAR_SAMP
// for the (non-null) values of one group. STDDEV_POP and STDDEV_SAMP are the
// square roots of VAR_POP and VAR_SAMP.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 7.i and 7.j
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.d.viii
fn eval_variance(name string, values []Value) !Value {
	mut xs := []f64{}
	for value in values {
		xs << value.as_f64()!
	}
	m := new_moments(xs, xs)

	if name.ends_with('_SAMP') && m.n == 1 {
		return null_double_precision()
	}

	variance := m.sxx / if name.ends_with('_POP') { m.n } else { m.n - 1 }
	if name.starts_with('STDDEV') {
		return scaled_value(math.sqrt(variance), [m.sx], false)!
	}

	return scaled_value(variance, [m.sx, m.sx], false)!
}

// eval_binary_set_function is the result of a binary set function, such as
// REGR_SLOPE(Y, X), for the pairs of (non-null) values of one group, where ys
// are the values of the <dependent variable expression> and xs are the values
// of the <independent variable expression>.
//
// CORR is the correlation coefficient, which has the same sign as the
// covariance. The standard defines it as the square root of REGR_R2, which
// can't be negative, but that's not the correlation that it describes, nor what
// any other database returns.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 8.b and 8.c
fn eval_binary_set_function(name string, ys []Value, xs []Value) !Value {
	mut fxs := []f64{}
	mut fys := []f64{}
	for i, y in ys {
		fxs << xs[i].as_f64()!
		fys << y.as_f64()!
	}
	m := new_moments(fxs, fys)

	if name == 'REGR_COUNT' {
		return new_integer_value(m.n)
	}

	if m.n == 0 || (name == 'COVAR_SAMP' && m.n == 1) {
		return null_double_precision()
	}

	// Every x (or every y) is the same, so there's no line that fits.
	if m.sxx == 0 && name in ['CORR', 'REGR_R2', 'REGR_SLOPE', 'REGR_INTERCEPT'] {
		return null_double_precision()
	}
	if m.syy == 0 && name == 'CORR' {
		return null_double_precision()
	}

	slope := m.sxy / m.sxx
	return match name {
		'REGR_SXX' { scaled_value(m.sxx, [m.sx, m.sx], false)! }
		'REGR_SYY' { scaled_value(m.syy, [m.sy, m.sy], false)! }
		'REGR_SXY' { scaled_value(m.sxy, [m.sx, m.sy], false)! }
		'REGR_AVGX' { scaled_value(m.mean_x, [m.sx], false)! }
		'REGR_AVGY' { scaled_value(m.mean_y, [m.sy], false)! }
		'COVAR_POP' { scaled_value(m.sxy / m.n, [m.sx, m.sy], false)! }
		'COVAR_SAMP' { scaled_value(m.sxy / (m.n - 1), [m.sx, m.sy], false)! }
		'CORR' { new_double_precision_value(m.sxy / (math.sqrt(m.sxx) * math.sqrt(m.syy))) }
		// REGR_R2 is 1 when every y is the same, because the line that fits is
		// horizontal (GR 8.c.xi.2).
		'REGR_R2' {
			new_double_precision_value(if m.syy == 0 { 1.0 } else { slope * (m.sxy / m.syy) })
		}
		'REGR_SLOPE' { scaled_value(slope, [m.sy, 1 / m.sx], true)! }
		// REGR_INTERCEPT
		else { scaled_value(m.mean_y - slope * m.mean_x, [m.sy], true)! }
	}
}
