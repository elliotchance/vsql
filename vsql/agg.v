// agg.v contains all the built in SQL aggregation functions.

module vsql

// COUNT(ANY) INTEGER
fn func_count(values []Value) ?Value {
	mut count := 0
	for value in values {
		if !value.is_null {
			count++
		}
	}

	return new_integer_value(count)
}

// MIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_min(values []Value) ?Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut min := values[0].f64_value
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		if value.f64_value < min {
			min = value.f64_value
		}
	}

	return new_double_precision_value(min)
}

// MAX(DOUBLE PRECISION) DOUBLE PRECISION
fn func_max(values []Value) ?Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut max := values[0].f64_value
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		if value.f64_value > max {
			max = value.f64_value
		}
	}

	return new_double_precision_value(max)
}

// SUM(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sum(values []Value) ?Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut sum := 0.0
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		sum += value.f64_value
	}

	return new_double_precision_value(sum)
}

// AVG(DOUBLE PRECISION) DOUBLE PRECISION
fn func_avg(values []Value) ?Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut sum := 0.0
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		sum += value.f64_value
	}

	return new_double_precision_value(sum / values.len)
}
