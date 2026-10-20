module vsql

import math

// ISO/IEC 9075-2:2016(E), 9.5, Result of data type combinations
//
// Specify the declared type of the result of certain combinations of values of
// compatible data types, such as the rows of a VALUES or the arguments to
// COALESCE.

const approximate_types = [SQLType.is_real, .is_double_precision]
const fractional_types = [SQLType.is_numeric, .is_decimal]
const time_types = [SQLType.is_time_without_time_zone, .is_time_with_time_zone]
const timestamp_types = [SQLType.is_timestamp_without_time_zone, .is_timestamp_with_time_zone]

// combine_types returns the type that two types can both be converted to, or
// none if they aren't compatible. Combining more types is done one at a time,
// since the result is the same in any order.
fn combine_types(t1 Type, t2 Type) ?Type {
	match true {
		// Syntax Rule 3a: the longest character string, which is only fixed-length
		// if all of them are. A size of 0 means there is no maximum length.
		t1.typ.is_string() && t2.typ.is_string() {
			size := if t1.size == 0 || t2.size == 0 { 0 } else { math.max(t1.size, t2.size) }
			if t1.typ == .is_character && t2.typ == .is_character {
				return Type{.is_character, size, 0, false}
			}

			return Type{.is_varchar, size, 0, false}
		}
		// Syntax Rule 3d: approximate numeric if any of them are.
		t1.typ.is_number() && t2.typ.is_number() && (t1.typ in approximate_types
			|| t2.typ in approximate_types) {
			if t1.typ == .is_real && t2.typ == .is_real {
				return Type{.is_real, 0, 0, false}
			}

			return Type{.is_double_precision, 0, 0, false}
		}
		// Syntax Rule 3c: exact numeric with the largest scale. The precision is
		// implementation-defined, so it's enough for the largest integer part and
		// scale.
		t1.typ.is_number() && t2.typ.is_number() {
			if t1.typ !in fractional_types && t2.typ !in fractional_types {
				return most_specific_type(t1, t2) or { return none }
			}

			typ := if t1.typ == .is_decimal || t2.typ == .is_decimal {
				SQLType.is_decimal
			} else {
				SQLType.is_numeric
			}

			// A NUMERIC or DECIMAL without a size (such as the result of a function)
			// has no limit.
			if (t1.typ in fractional_types && t1.size == 0) || (t2.typ in fractional_types && t2.size == 0) {
				return Type{typ, 0, 0, false}
			}

			scale := math.max(t1.scale, t2.scale)
			digits := math.max(t1.integer_digits(), t2.integer_digits())

			return Type{typ, digits + scale, scale, false}
		}
		// Syntax Rule 3f: all BOOLEAN.
		t1.typ == .is_boolean && t2.typ == .is_boolean {
			return Type{.is_boolean, 0, 0, false}
		}
		// Syntax Rule 3e: the same datetime type (DATE, TIME or TIMESTAMP), with
		// the largest fractional seconds precision. It has a time zone if any of
		// them do.
		t1.typ == .is_date && t2.typ == .is_date {
			return Type{.is_date, 0, 0, false}
		}
		t1.typ in time_types && t2.typ in time_types {
			typ := if t1.has_time_zone() || t2.has_time_zone() {
				SQLType.is_time_with_time_zone
			} else {
				SQLType.is_time_without_time_zone
			}

			return Type{typ, math.max(t1.size, t2.size), 0, false}
		}
		t1.typ in timestamp_types && t2.typ in timestamp_types {
			typ := if t1.has_time_zone() || t2.has_time_zone() {
				SQLType.is_timestamp_with_time_zone
			} else {
				SQLType.is_timestamp_without_time_zone
			}

			return Type{typ, math.max(t1.size, t2.size), 0, false}
		}
		else {
			return none
		}
	}
}

// convert_to_combined_type converts a value to the type from combine_types.
// Only a value of a different type (such as a SMALLINT in an INTEGER column)
// is cast, and it keeps its own length or precision. The declared sizes of some
// expressions aren't exact yet, so casting to them could truncate the value.
fn convert_to_combined_type(mut conn Connection, context string, v Value, typ Type) !Value {
	if v.typ.typ == typ.typ {
		return v
	}

	size := if typ.typ.is_number() { 0 } else { v.typ.size }

	return cast(mut conn, context, v, Type{typ.typ, size, 0, false})!
}

// integer_digits is the number of digits before the decimal point that an exact
// numeric type can hold.
fn (t Type) integer_digits() int {
	return match t.typ {
		.is_smallint { 5 }
		.is_integer { 10 }
		.is_bigint { 19 }
		else { t.size - t.scale }
	}
}
