module vsql

// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>
//
// Specify a data conversion.

type CastOperand = NullSpecification | ValueExpression

fn (e CastOperand) pstr(params map[string]Value) string {
	return match e {
		ValueExpression, NullSpecification {
			e.pstr(params)
		}
	}
}

fn (e CastOperand) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, NullSpecification {
			return e.compile(mut c)!
		}
	}
}

struct CastSpecification {
	expr   CastOperand
	target Type
}

fn (e CastSpecification) pstr(params map[string]Value) string {
	return 'CAST(${e.expr.pstr(params)} AS ${e.target})'
}

fn (e CastSpecification) compile(mut c Compiler) !CompileResult {
	compiled_expr := e.expr.compile(mut c)!

	return CompileResult{
		run:          fn [e, compiled_expr] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_expr.run(mut conn, data, params)!

			if !value.is_null && value.typ.uses_string() && e.target.uses_time() {
				return cast_string_to_datetime(mut conn, value, e.target)!
			}

			return cast(mut conn, 'for CAST', value, e.target)!
		}
		typ:          e.target
		contains_agg: compiled_expr.contains_agg
	}
}

// cast_string_to_datetime converts a character string to a DATE, TIME or
// TIMESTAMP. Leading and trailing spaces are ignored, then the string must be a
// valid unquoted datetime string (such as "2022-06-30") for the target type. A
// time zone is added or removed in the same way as casting between the datetime
// types.
//
// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, General Rules, 14a, 16a,
// 17a, 18a and 19a
fn cast_string_to_datetime(mut conn Connection, v Value, to Type) !Value {
	s := v.string_value().trim(' ')
	value := match to.typ {
		.is_date {
			new_date_value(s) or { return sqlstate_22007() }
		}
		.is_time_with_time_zone, .is_time_without_time_zone {
			new_time_value(s) or { return sqlstate_22007() }
		}
		else {
			new_timestamp_value(s) or { return sqlstate_22007() }
		}
	}

	return cast(mut conn, 'for CAST', value, to)!
}
