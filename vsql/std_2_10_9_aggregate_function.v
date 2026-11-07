module vsql

import math

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>
//
// Specify a value computed from a collection of rows.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.16 (Data analysis operations involving tables)

type AggregateFunction = AggregateFunctionCount | ListaggSetFunction | RoutineInvocation

fn (e AggregateFunction) pstr(params map[string]Value) string {
	return match e {
		AggregateFunctionCount { 'COUNT(*)${filter_pstr(e.filter, params)}' }
		ListaggSetFunction { e.pstr(params) }
		RoutineInvocation { e.pstr(params) }
	}
}

fn (e AggregateFunction) compile(mut c Compiler) !CompileResult {
	match e {
		AggregateFunctionCount {
			// COUNT(*) has no argument, so its filter doesn't change the query that
			// it's an aggregate of (this one).
			aggregated_columns := c.aggregated_columns
			c.aggregated_columns = []
			compile_filter(mut c, e.filter, e.pstr(c.params))!
			c.aggregated_columns = aggregated_columns

			compiled := Identifier{
				custom_id:  e.pstr(c.params)
				custom_typ: new_type('INTEGER', 0, 0)
			}.compile(mut c)!

			// An aggregate function of an outer query is calculated by that query
			// (see Subquery.plan), and is a value of its row.
			scope := c.aggregation_scope()!
			if scope >= 0 {
				// This isn't seen as an aggregate function by an enclosing one, because
				// it's a value of this query.
				//
				// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 1
				if c.in_aggregate {
					return sqlstate_42601('nested set function: ${e.pstr(c.params)}')
				}

				c.conn.subquery_scopes[scope].aggregates << AggregateFunction(e)

				return CompileResult{
					run:          fn [compiled, scope] (mut conn Connection, data Row, params map[string]Value) !Value {
						return compiled.run(mut conn, conn.subquery_scopes[scope].row, params)!
					}
					typ:          new_type('INTEGER', 0, 0)
					contains_agg: false
				}
			}

			c.aggregates << e

			return CompileResult{
				run:          fn [compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
					return compiled.run(mut conn, data, params)!
				}
				typ:          new_type('INTEGER', 0, 0)
				contains_agg: true
			}
		}
		ListaggSetFunction {
			return e.compile(mut c)!
		}
		RoutineInvocation {
			return e.compile(mut c)!
		}
	}
}

struct AggregateFunctionCount {
	filter ?&BooleanValueExpression
}

// with_filter adds the <search condition> of a <filter clause> to a general set
// function or a LISTAGG.
fn with_filter(e AggregateFunction, filter BooleanValueExpression) AggregateFunction {
	if e is ListaggSetFunction {
		return ListaggSetFunction{
			...e
			filter: &BooleanValueExpression{
				...filter
			}
		}
	}

	f := e as RoutineInvocation
	return RoutineInvocation{
		function_name: f.function_name
		args:          f.args
		distinct:      f.distinct
		filter:        &BooleanValueExpression{
			...filter
		}
	}
}

// aggregate_result is the result of the aggregate function e, after its
// arguments (and filter) have been compiled with in_aggregate set, where typ is
// its declared type and in_aggregate is whether it's in the argument of another
// aggregate function. The result is calculated for each group (see
// GroupOperation), and stored in the row by the name of the function.
fn aggregate_result(mut c Compiler, e AggregateFunction, typ Type, in_aggregate bool) !CompileResult {
	compiled := Identifier{
		custom_id:  e.pstr(c.params)
		custom_typ: typ
	}.compile(mut c)!

	// An aggregate function of an outer query is calculated by that query
	// (see Subquery.plan), and is a value of its row.
	scope := c.aggregation_scope()!
	if scope >= 0 {
		// This isn't seen as an aggregate function by an enclosing one, because
		// it's a value of this query.
		//
		// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 1
		if in_aggregate {
			return sqlstate_42601('nested set function: ${e.pstr(c.params)}')
		}

		c.conn.subquery_scopes[scope].aggregates << e

		return CompileResult{
			run:          fn [compiled, scope] (mut conn Connection, data Row, params map[string]Value) !Value {
				return compiled.run(mut conn, conn.subquery_scopes[scope].row, params)!
			}
			typ:          compiled.typ
			contains_agg: false
		}
	}

	c.aggregates << e

	return compiled.with_agg(true)
}

fn filter_pstr(filter ?&BooleanValueExpression, params map[string]Value) string {
	if f := filter {
		return ' FILTER (WHERE ${f.pstr(params)})'
	}

	return ''
}

// compile_filter checks the <search condition> of the <filter clause> of the
// aggregate function agg. Like the argument of an aggregate function, it can use
// any column of a grouped query, and it can't contain an aggregate function or
// a subquery (see Subquery.plan). There are no window functions.
//
// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 5
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 8
fn compile_filter(mut c Compiler, filter ?&BooleanValueExpression, agg string) ! {
	f := filter or { return }

	in_aggregate := c.in_aggregate
	c.in_aggregate = true
	defer {
		c.in_aggregate = in_aggregate
	}

	columns := c.aggregated_columns.len
	compiled := f.compile(mut c)!
	if compiled.contains_agg {
		return sqlstate_42601('nested set function: ${agg}')
	}

	for column in c.aggregated_columns[columns..] {
		if column.scope >= 0 {
			return sqlstate_42601('outer reference in FILTER: ${column.name}')
		}
	}

	if compiled.typ.typ != .is_boolean {
		return sqlstate_42804('in FILTER', 'BOOLEAN', compiled.typ.str())
	}
}

// filter_rows is the rows of a group that an aggregate function is applied to.
// If there's a <filter clause>, they're only the rows where its search condition
// is True.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 4
fn filter_rows(mut c Compiler, filter ?&BooleanValueExpression, rows []Row) ![]Row {
	f := filter or { return rows }

	compiled := f.compile(mut c)!
	mut result := []Row{}
	for row in rows {
		if compiled.run(mut c.conn, row, c.params)!.bool_value() == .is_true {
			result << row
		}
	}

	return result
}

// non_null_values removes NULLs before a general set function is applied. If
// all values are NULL (or there are no values) the result will be NULL.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.a
fn non_null_values(values []Value) []Value {
	return values.filter(!it.is_null)
}

// distinct_values removes NULLs and duplicates for a general set function with
// DISTINCT, such as COUNT(DISTINCT x). Values are duplicates if they're equal
// with =, so 1.5 and 1.50 (or 'a' and 'a ') are the same value. The first of
// each set of duplicates is kept.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.b
//
// Values that are equal with = have the same PRIMARY KEY encoding, and values
// that aren't have different ones, so each value is found by its key rather
// than compared with every value already kept. The encoding depends on the type,
// so each value is cast to the declared type of the argument (typ) first.
fn distinct_values(mut conn Connection, values []Value, typ Type) ![]Value {
	mut seen := map[string]bool{}
	mut result := []Value{}
	for value in non_null_values(values) {
		mut key := new_empty_bytes()
		write_key_value(mut key, cast(mut conn, '', value, typ)!, typ.typ)
		k := key.bytes().bytestr()
		if k !in seen {
			seen[k] = true
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

	// MAX and MIN have the type of their argument (SR 7.f), and EVERY, ANY and
	// SOME are a BOOLEAN like their argument (SR 7.e). So does AVG, which
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

	// EVERY is TRUE if every value is TRUE, and ANY (or SOME) is TRUE if any
	// value is TRUE. Unknown values are NULLs, which have been removed.
	//
	// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.d.vi and 7.d.vii
	if name == 'EVERY' {
		return new_boolean_value(values.all(it.bool_value() == .is_true))
	}
	if name in ['ANY', 'SOME'] {
		return new_boolean_value(values.any(it.bool_value() == .is_true))
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

// ListaggSetFunction is a <listagg set function>, such as
// "LISTAGG(x, ', ') WITHIN GROUP (ORDER BY x)". value is a reference because
// a CharacterValueExpression can contain an AggregateFunction.
struct ListaggSetFunction {
	distinct  bool
	value     &CharacterValueExpression
	separator Value
	overflow  ListaggOverflow
	order     []SortSpecification
	filter    ?&BooleanValueExpression
}

// ListaggOverflow is the <listagg overflow clause>. Without one, it's ON
// OVERFLOW ERROR (truncate is false). The filler is '...' if it isn't
// specified.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.f and 11.g
struct ListaggOverflow {
	truncate   bool
	filler     Value = new_varchar_value('...')
	with_count bool
}

fn new_listagg_set_function(distinct bool, value CharacterValueExpression, separator Value, overflow ListaggOverflow, order []SortSpecification) ListaggSetFunction {
	return ListaggSetFunction{
		distinct:  distinct
		value:     &value
		separator: separator
		overflow:  overflow
		order:     order
	}
}

fn (e ListaggSetFunction) pstr(params map[string]Value) string {
	quantifier := if e.distinct { 'DISTINCT ' } else { '' }
	mut overflow := ''
	if e.overflow.truncate {
		count := if e.overflow.with_count { 'WITH' } else { 'WITHOUT' }
		overflow = ' ON OVERFLOW TRUNCATE ${e.overflow.filler.pstr(params)} ${count} COUNT'
	}
	order := e.order.map(it.pstr(params)).join(', ')

	return 'LISTAGG(${quantifier}${e.value.pstr(params)}, ${e.separator.pstr(params)}${overflow}) WITHIN GROUP (ORDER BY ${order})${filter_pstr(e.filter, params)}'
}

// listagg_type is the declared type of the result of LISTAGG. It's a VARCHAR
// with the maximum length (MLRT), rather than a CLOB, which isn't supported.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.d
fn listagg_type() Type {
	return new_type('CHARACTER VARYING', max_character_length, 0)
}

fn (e ListaggSetFunction) compile(mut c Compiler) !CompileResult {
	// Like the argument of a general set function, the argument and the sort
	// keys can use any column of a grouped query, and the columns that they use
	// find the query that it's an aggregate of (see aggregation_scope). They
	// can't contain a subquery (see Subquery.plan), and there are no window
	// functions.
	//
	// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.a
	in_aggregate := c.in_aggregate
	aggregated_columns := c.aggregated_columns
	c.in_aggregate = true
	c.aggregated_columns = []
	defer {
		c.in_aggregate = in_aggregate
		c.aggregated_columns = aggregated_columns
	}

	name := e.pstr(c.params)
	value := e.value.compile(mut c)!
	mut contains_agg := value.contains_agg
	for spec in e.order {
		if spec.expr.compile(mut c)!.contains_agg {
			contains_agg = true
		}
	}
	if contains_agg {
		return sqlstate_42601('nested set function: ${name}')
	}

	if !value.typ.typ.is_string() {
		return sqlstate_42883('function does not exist: LISTAGG(${value.typ})')
	}

	// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.e and 11.g
	check_listagg_literal(e.separator)!
	check_listagg_literal(e.overflow.filler)!

	compile_filter(mut c, e.filter, name)!

	return aggregate_result(mut c, AggregateFunction(e), listagg_type(), in_aggregate)!
}

// check_listagg_literal checks that the separator or the filler of a LISTAGG
// isn't longer than the result can be.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.e and 11.g
fn check_listagg_literal(literal Value) ! {
	if literal.string_value().runes().len > max_character_length {
		return sqlstate_42601('LISTAGG literal is longer than the maximum length of ${max_character_length}')
	}
}

// eval returns the result of the LISTAGG for the rows of a group (after its
// filter), and whether a null value was eliminated.
//
// The rows are sorted by the <within group specification> first, and each
// value is then in the order of its row. With DISTINCT, the first of the
// duplicate values (in that order) is kept, so the position of each value is
// where it's first seen. Rows that are equal for every sort key are in the
// order they were read in (see OrderOperation.execute). Every string type can
// be compared, so the value can always be an operand of a grouping operation
// for DISTINCT.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.b
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 11
fn (e ListaggSetFunction) eval(mut c Compiler, rows []Row) !(Value, bool) {
	mut order := new_order_operation(e.order, c.params, c.conn, []Column{}, c.tables,
		map[string][]ValueExpression{})
	sorted := order.execute(rows)!

	compiled := e.value.compile(mut c)!
	mut values := []Value{}
	mut null_eliminated := false
	for row in sorted {
		value := compiled.run(mut c.conn, row, c.params)!
		if value.is_null {
			null_eliminated = true
		}
		values << value
	}

	values = if e.distinct {
		distinct_values(mut c.conn, values, compiled.typ)!
	} else {
		non_null_values(values)
	}

	if values.len == 0 {
		return Value{
			typ:     listagg_type()
			is_null: true
		}, null_eliminated
	}

	result := listagg_result(values.map(it.string_value()), e.separator.string_value(),
		e.overflow, max_character_length)!

	return Value{
		...new_varchar_value(result)
		typ: listagg_type()
	}, null_eliminated
}

// listagg_result joins the values with the separator. If that's longer than
// mlrt characters, it's an error, or it's truncated after as many of the values
// as fit with the filler (and the number of values that were removed, WITH
// COUNT) after them.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 3.d, 11.f and 11.g
fn listagg_result(values []string, separator string, overflow ListaggOverflow, mlrt int) !string {
	result := values.join(separator)
	// The number of characters can't be more than the number of bytes.
	if result.len <= mlrt || result.runes().len <= mlrt {
		return result
	}

	if !overflow.truncate {
		return sqlstate_22001(new_type('CHARACTER VARYING', mlrt, 0))
	}

	// LTFP1 is the separator and the filler.
	ltfp1 := separator + overflow.filler.string_value()
	ltfp1_len := ltfp1.runes().len
	n := values.len

	// The greatest i (1 <= i < N) where the first i values (LIRPi) fit, or 0 if
	// there's no such i. With a count, the space it needs depends on i.
	separator_len := separator.runes().len
	mut i := 0
	mut prefix_len := 0
	for j in 1 .. n {
		prefix_len += values[j - 1].runes().len
		if j > 1 {
			prefix_len += separator_len
		}
		if prefix_len > mlrt {
			break
		}

		limit := if overflow.with_count {
			mlrt - ltfp1_len - (n - j).str().len - 2
		} else {
			mlrt - ltfp1_len
		}
		if prefix_len <= limit {
			i = j
		}
	}

	if overflow.with_count {
		if i == 0 {
			lir2 := '${ltfp1}(${n})'
			return if lir2.runes().len > mlrt { '...(${n})' } else { lir2 }
		}

		return '${values[..i].join(separator)}${ltfp1}(${n - i})'
	}

	if i == 0 {
		return if ltfp1_len > mlrt { '...' } else { ltfp1 }
	}

	return values[..i].join(separator) + ltfp1
}
